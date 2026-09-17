'use strict';
// These are offline tests with a mocked AdsApp, NOT live Google Ads API validation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, 'setup-google-ads.js'), 'utf8');
const clone = value => JSON.parse(JSON.stringify(value));
const CID = '7904459880', OWNER = 'customers/' + CID;
const ACTION = OWNER + '/conversionActions/77';
const eligible = (id = 77, changes = {}) => ({resourceName: OWNER + '/conversionActions/' + id,
  name: 'SoulBuddy downloads', type: 'GOOGLE_PLAY_DOWNLOAD', appId: 'app.soulbuddy.soulbuddy',
  status: 'ENABLED', primaryForGoal: true, ...changes});
const fakeImages = () => [['landscape', 1200, 628], ['square', 1200, 1200], ['portrait', 1200, 1500]]
  .map(([shape, width, height], i) => {
    const data = Buffer.from([255, 216, i, 255, 217]);
    const sha256 = crypto.createHash('sha256').update(data).digest('hex');
    return {name: 'SoulBuddy transformation ' + shape + ' ' + sha256.slice(0, 16), width, height,
      bytes: data.length, sha256, data: data.toString('base64')};
  });
function harness(options = {}) {
  const state = {queries: [], mutations: [], logs: []};
  const images = options.images === undefined ? fakeImages() : options.images;
  const utilities = {
    DigestAlgorithm: {SHA_256: 'sha256'},
    base64Decode: value => Array.from(Buffer.from(value, 'base64')),
    computeDigest: (algorithm, bytes) => Array.from(crypto.createHash(algorithm).update(Buffer.from(bytes)).digest()),
    formatDate: (_date, timezone, format) => {
      assert.equal(timezone, options.timezone || 'Africa/Lagos');
      assert.equal(format, 'yyyy-MM-dd');
      return options.today || '2026-09-17';
    }
  };
  const sandbox = {console: {log: (...args) => state.logs.push(args.join(' '))}, Utilities: utilities,
    AdsApp: {
      currentAccount: () => ({getCustomerId: () => options.customerId || '790-445-9880',
        getCurrencyCode: () => options.currency || 'USD', getTimeZone: () => options.timezone || 'Africa/Lagos'}),
      search: (query, settings) => {
        assert.equal(settings.apiVersion, 'v25'); state.queries.push(query);
        let rows;
        if (query.includes('FROM campaign ') && query.includes('campaign.name =')) rows = options.named || [];
        else if (query.includes('FROM campaign ')) rows = options.active || [];
        else if (query.includes('FROM customer')) rows = options.customerRows || [{customer: {
          id: CID, manager: Boolean(options.manager), conversionTrackingSetting: {
            googleAdsConversionCustomer: options.owner === undefined ? OWNER : options.owner}}}];
        else if (query.includes('FROM geo_target_constant ')) rows = options.countries ||
          [{geoTargetConstant: {resourceName: 'geoTargetConstants/2566', name: 'Nigeria'}}];
        else if (query.includes('FROM language_constant ')) rows = options.languages ||
          [{languageConstant: {resourceName: 'languageConstants/1000'}}];
        else if (query.includes('FROM conversion_action ')) rows =
          (options.conversions === undefined ? [eligible()] : options.conversions).map(conversionAction => ({conversionAction}));
        else if (query.includes('FROM asset ')) rows = (options.assets || []).map(asset => ({asset}));
        else throw new Error('Unexpected query: ' + query);
        let i = 0;
        return {hasNext: () => i < rows.length, next: () => rows[i++]};
      },
      mutateAll: (operations, settings) => {
        state.mutations.push({operations: clone(operations), settings: clone(settings)});
        if (options.transportError) throw new Error('network timeout');
        if (options.shortResponse) return [];
        return operations.map((_operation, index) => ({
          isSuccessful: () => !options.apiFailure,
          getErrorMessages: () => ['test validation rejection'],
          getResourceName: () => options.badResource || OWNER + '/campaigns/' + (9000 + index)
        }));
      },
      getExecutionInfo: () => ({isPreview: () => Boolean(options.preview)})
    }};
  vm.createContext(sandbox);
  const code = options.code || source.replace('const EMBEDDED_IMAGES = []; // @SOULBUDDY_IMAGES@',
    'const EMBEDDED_IMAGES = ' + JSON.stringify(images) + ';');
  vm.runInContext(code + '\nglobalThis.h = {main, PILOT, HEADLINES, DESCRIPTIONS, EMBEDDED_IMAGES, makePlan,' +
    'planConversion, buildOperations, validateImages, validateText, compareResourceIds, quoted, toMicros, validDate, addDays};', sandbox);
  return {h: sandbox.h, state, utilities};
}
function run(options = {}) {const x = harness(options); x.h.main(); return x;}
function operations(x, key) {return x.state.mutations[0].operations.filter(op => op[key]).map(op => op[key].create);}

for (const [currency, daily] of [['USD', 3], ['NGN', 3000], ['EUR', 3], ['GBP', 2], ['CAD', 4], ['AUD', 4]]) {
  test('zero-configuration ' + currency + ' allowance is explicit and read automatically', () => {
    const x = run({currency});
    assert.equal(operations(x, 'campaignBudgetOperation')[0].amountMicros, String(daily * 1000000));
    assert.match(x.state.logs.join('\n'), new RegExp('"averageDailyBudget": ' + daily));
    assert.match(x.state.logs.join('\n'), new RegExp('"conservativeWindowExposureBeforeTaxes": ' + daily * 28));
  });
}
test('all campaign resources and three embedded image assets are atomic; parent always paused', () => {
  const x = run();
  assert.equal(x.state.mutations.length, 1);
  assert.deepEqual(x.state.mutations[0].settings, {apiVersion: 'v25', partialFailure: false});
  assert.equal(x.state.mutations[0].operations.length, 9);
  const campaign = operations(x, 'campaignOperation')[0];
  assert.equal(campaign.status, 'PAUSED');
  assert.equal(campaign.advertisingChannelType, 'MULTI_CHANNEL');
  assert.equal(campaign.advertisingChannelSubType, 'APP_CAMPAIGN');
  assert.equal(campaign.appCampaignSetting.appId, 'app.soulbuddy.soulbuddy');
  assert.equal(campaign.appCampaignSetting.appStore, 'GOOGLE_APP_STORE');
  assert.equal(campaign.appCampaignSetting.biddingStrategyGoalType, 'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST');
  assert.deepEqual(campaign.maximizeConversions, {});
  assert.equal(campaign.targetCpa, undefined);
  assert.equal(campaign.startDateTime, '2026-09-17 00:00:00');
  assert.equal(campaign.endDateTime, '2026-09-30 23:59:59');
  assert.equal(campaign.geoTargetTypeSetting.positiveGeoTargetType, 'PRESENCE');
  assert.deepEqual(campaign.selectiveOptimization.conversionActions, [ACTION]);
  const assets = operations(x, 'assetOperation');
  assert.equal(assets.length, 3);
  const ad = operations(x, 'adGroupAdOperation')[0].ad.appAd;
  assert.equal(ad.headlines.length, 5); assert.equal(ad.descriptions.length, 5);
  assert.deepEqual(ad.images.map(item => item.asset), assets.map(asset => asset.resourceName));
  assert.equal(ad.youtubeVideos, undefined);
  assert.equal(operations(x, 'campaignBudgetOperation')[0].explicitlyShared, false);
  for (const op of x.state.mutations[0].operations) assert.deepEqual(Object.keys(Object.values(op)[0]), ['create']);
  assert.doesNotMatch(JSON.stringify(x.state.mutations), /userList|audience|keyword|customerMatch|youtubeVideo|videoAsset/);
  assert.match(x.state.logs.join('\n'), /CREATED PAUSED/);
});
test('fresh account gets exactly one package-specific install action in the same atomic request', () => {
  const x = run({conversions: []});
  assert.equal(x.state.mutations[0].operations.length, 10);
  const action = operations(x, 'conversionActionOperation')[0];
  assert.equal(action.type, 'GOOGLE_PLAY_DOWNLOAD');
  assert.equal(action.category, 'DOWNLOAD'); assert.equal(action.appId, 'app.soulbuddy.soulbuddy');
  assert.equal(action.primaryForGoal, true); assert.equal(action.status, 'ENABLED');
  assert.equal(action.countingType, 'ONE_PER_CLICK'); assert.equal(action.valueSettings.defaultValue, 0);
  assert.equal(action.valueSettings.alwaysUseDefaultValue, true);
  assert.equal(action.mobileAppVendor, undefined); // output-only field must not be supplied
  assert.deepEqual(operations(x, 'campaignOperation')[0].selectiveOptimization.conversionActions, [action.resourceName]);
  assert.match(x.state.logs.join('\n'), /account-level measurement resource/);
});
test('preview builds/validates unchanged request but accurately reports no persistence', () => {
  const x = run({preview: true, conversions: []});
  assert.match(x.state.logs.join('\n'), /PREVIEW PASSED/);
  assert.doesNotMatch(x.state.logs.join('\n'), /CREATED PAUSED/);
  assert.equal(operations(x, 'campaignOperation')[0].status, 'PAUSED');
});
for (const status of ['ENABLED', 'PAUSED', 'REMOVED']) {
  test('same-named ' + status + ' campaign blocks duplication and changes', () => {
    const x = run({named: [{campaign: {name: 'same', status}}]});
    assert.equal(x.state.mutations.length, 0); assert.equal(x.state.queries.length, 1);
  });
}
for (const status of ['ENABLED', 'PAUSED']) {
  test('other SoulBuddy ' + status + ' campaign prevents a second pilot', () => {
    const x = run({active: [{campaign: {name: 'legacy', status}}]});
    assert.equal(x.state.mutations.length, 0); assert.equal(x.state.queries.length, 2);
  });
}
for (const [name, options] of [
  ['wrong account', {customerId: '123-456-7890'}], ['unsupported currency', {currency: 'JPY'}],
  ['prototype currency key', {currency: 'toString'}], ['manager account', {manager: true}],
  ['missing conversion owner', {owner: ''}], ['foreign conversion owner with no action', {owner: 'customers/1234', conversions: []}],
  ['ambiguous customer', {customerRows: []}], ['missing country', {countries: []}], ['missing language', {languages: []}],
  ['disabled existing conversion', {conversions: [eligible(77, {status: 'HIDDEN'})]}],
  ['removed existing conversion', {conversions: [eligible(77, {status: 'REMOVED'})]}],
  ['secondary existing conversion', {conversions: [eligible(77, {primaryForGoal: false})]}],
  ['wrong app conversion', {conversions: [eligible(77, {appId: 'another.app'})]}],
  ['wrong conversion type', {conversions: [eligible(77, {type: 'WEBPAGE'})]}],
  ['invalid local date', {today: '2026-02-30'}], ['date overflow', {today: '9999-12-31'}],
  ['no bundled images', {images: []}]
]) {
  test(name + ' fails before any mutation', () => {
    const x = harness(options); assert.throws(() => x.h.main()); assert.equal(x.state.mutations.length, 0);
  });
}
test('chooses one oldest eligible install ID deterministically, never duplicate counting', () => {
  const x = run({conversions: [eligible(100), eligible(9), eligible(77)]});
  assert.equal(operations(x, 'conversionActionOperation').length, 0);
  assert.deepEqual(operations(x, 'campaignOperation')[0].selectiveOptimization.conversionActions,
    [OWNER + '/conversionActions/9']);
});
test('manager-owned eligible conversions can be reused, never written by child account', () => {
  const ref = 'customers/1234/conversionActions/77';
  const x = run({owner: 'customers/1234', conversions: [eligible(77, {resourceName: ref})]});
  assert.deepEqual(operations(x, 'campaignOperation')[0].selectiveOptimization.conversionActions, [ref]);
  assert.equal(operations(x, 'conversionActionOperation').length, 0);
});
test('existing matching image assets are reused without upload', () => {
  const assets = fakeImages().map((image, i) => ({resourceName: OWNER + '/assets/' + (100 + i),
    name: image.name, type: 'IMAGE', imageAsset: {fullSize: {widthPixels: String(image.width), heightPixels: String(image.height)}}}));
  const x = run({assets});
  assert.equal(operations(x, 'assetOperation').length, 0);
  assert.deepEqual(operations(x, 'adGroupAdOperation')[0].ad.appAd.images.map(image => image.asset),
    assets.map(asset => asset.resourceName));
});
for (const defect of ['type', 'width', 'owner']) {
  test('image reuse rejects wrong ' + defect, () => {
    const image = fakeImages()[0];
    const asset = {name: image.name, resourceName: OWNER + '/assets/1', type: 'IMAGE',
      imageAsset: {fullSize: {widthPixels: 1200, heightPixels: 628}}};
    if (defect === 'type') asset.type = 'YOUTUBE_VIDEO';
    if (defect === 'width') asset.imageAsset.fullSize.widthPixels = 99;
    if (defect === 'owner') asset.resourceName = 'customers/1234/assets/1';
    const x = harness({assets: [asset]}); assert.throws(() => x.h.main()); assert.equal(x.state.mutations.length, 0);
  });
}
for (const defect of ['checksum', 'base64', 'bytes', 'name', 'dimensions', 'missing-ratio']) {
  test('embedded image ' + defect + ' corruption fails closed', () => {
    const images = fakeImages();
    if (defect === 'checksum') images[0].sha256 = '0'.repeat(64);
    if (defect === 'base64') images[0].data = 'not valid!';
    if (defect === 'bytes') images[0].bytes += 1;
    if (defect === 'name') images[0].name = 'arbitrary';
    if (defect === 'dimensions') images[0].width = 123;
    if (defect === 'missing-ratio') images[0].height = 1200;
    const x = harness({images}); assert.throws(() => x.h.main()); assert.equal(x.state.mutations.length, 0);
  });
}
test('API rejection is surfaced; no retry or false success', () => {
  const x = harness({apiFailure: true, conversions: []});
  assert.throws(() => x.h.main(), /Atomic request rejected/);
  assert.equal(x.state.mutations.length, 1); assert.doesNotMatch(x.state.logs.join('\n'), /CREATED PAUSED/);
});
test('ambiguous transport error never retries or assumes nothing was created', () => {
  const x = harness({transportError: true});
  assert.throws(() => x.h.main(), /transport error can hide a committed paused result/);
  assert.equal(x.state.mutations.length, 1);
});
test('short response requires inspection', () => {
  const x = harness({shortResponse: true}); assert.throws(() => x.h.main(), /Unexpected Google Ads response/);
});
test('returned campaign account is validated', () => {
  const x = harness({badResource: 'customers/1234/campaigns/1'});
  assert.throws(() => x.h.main(), /Unexpected campaign resource/);
});
test('uses the account-local calendar including leap and year boundaries', () => {
  const x = run({today: '2028-02-28', timezone: 'America/Los_Angeles'});
  assert.equal(operations(x, 'campaignOperation')[0].endDateTime, '2028-03-12 23:59:59');
  assert.equal(x.h.addDays('2026-12-31', 1), '2027-01-01');
});
test('integer IDs above JS precision are sorted as decimal strings', () => {
  const {h} = harness();
  assert.equal(h.compareResourceIds('x/9999999999999999999', 'x/10000000000000000000'), -1);
});
test('all copy is within limits, query literals are escaped and money is exact', () => {
  const {h} = harness();
  h.validateText(h.HEADLINES, 30); h.validateText(h.DESCRIPTIONS, 90);
  assert.equal(h.toMicros(3000), 3000000000); assert.equal(h.toMicros(3), 3000000);
  assert.throws(() => h.toMicros(Infinity)); assert.throws(() => h.toMicros(-1));
  assert.equal(h.quoted("a'b\\c"), "'a\\'b\\\\c'");
});
test('actual distributed bundle verifies real images and constructs the full request', () => {
  const filename = path.join(__dirname, 'ready', 'SoulBuddy-Ready-to-Run.js');
  assert.ok(fs.existsSync(filename), 'Run build-ready-script.py before the test suite');
  const code = fs.readFileSync(filename, 'utf8');
  const x = run({code, conversions: []});
  assert.equal(operations(x, 'assetOperation').length, 3);
  for (const asset of operations(x, 'assetOperation')) assert.ok(Buffer.from(asset.imageAsset.data, 'base64').length > 10000);
  assert.ok(Buffer.byteLength(code) < 1024 * 1024);
  assert.doesNotMatch(code, /UrlFetchApp|DriveApp|eval\(|new Function\(/);
});
