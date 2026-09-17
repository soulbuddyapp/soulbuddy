'use strict';
// Offline contract/safety tests. These mock AdsApp, not Google's live validation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, 'setup-google-ads.js'), 'utf8');
const clone = value => JSON.parse(JSON.stringify(value));
const CUSTOMER = '1234567890';
const CONVERSION = 'customers/' + CUSTOMER + '/conversionActions/77';
const context = {customerId: CUSTOMER, currency: 'USD', today: '2026-09-17'};

function harness(overrides = {}) {
  const state = {queries: [], mutations: [], logs: []};
  const sandbox = {
    console: {log: (...args) => state.logs.push(args.join(' '))},
    Utilities: {formatDate: (_date, zone, format) => {
      assert.equal(zone, 'Africa/Lagos');
      assert.equal(format, 'yyyy-MM-dd');
      return context.today;
    }},
    AdsApp: {
      currentAccount: () => ({getCustomerId: () => '123-456-7890',
        getCurrencyCode: () => 'USD', getTimeZone: () => 'Africa/Lagos'}),
      search: (query, options) => {
        assert.equal(options.apiVersion, 'v25');
        state.queries.push(query);
        let rows;
        if (query.includes('FROM campaign ')) rows = overrides.existing || [];
        else if (query.includes('FROM geo_target_constant ')) rows = overrides.countries ||
          [{geoTargetConstant: {resourceName: 'geoTargetConstants/2566', name: 'Nigeria'}}];
        else if (query.includes('FROM language_constant ')) rows =
          [{languageConstant: {resourceName: 'languageConstants/1000'}}];
        else if (query.includes('FROM conversion_action ')) rows = overrides.conversions ||
          [{conversionAction: {resourceName: CONVERSION, name: 'SoulBuddy downloads',
            appId: 'app.soulbuddy.soulbuddy', primaryForGoal: true}}];
        else if (query.includes('FROM asset ')) rows = overrides.assets || [];
        else throw new Error('Unexpected query: ' + query);
        let index = 0;
        return {hasNext: () => index < rows.length, next: () => rows[index++]};
      },
      mutateAll: (operations, options) => {
        state.mutations.push({operations: clone(operations), options: clone(options)});
        if (overrides.transportError) throw new Error('Simulated transport failure');
        if (overrides.shortResponse) return [];
        return operations.map((_op, index) => ({
          isSuccessful: () => !overrides.apiFailure,
          getErrorMessages: () => ['Simulated API validation error'],
          getResourceName: () => 'customers/' + CUSTOMER + '/campaigns/' + (9000 + index)
        }));
      },
      getExecutionInfo: () => ({isPreview: () => Boolean(overrides.preview)})
    }
  };
  vm.createContext(sandbox);
  vm.runInContext(source + '\nglobalThis.h = {CONFIG, main, validateConfig, buildOperations,' +
    'chooseConversion, gaqlString, toMicros, addDays, validDate};', sandbox);
  const h = sandbox.h;
  Object.assign(h.CONFIG, {expectedCustomerId: CUSTOMER, expectedCurrency: 'USD',
    countryCode: 'NG', dailyBudget: 5});
  return {h, state, config: h.CONFIG};
}
function create(overrides, edits = {}) {
  const x = harness(overrides);
  Object.assign(x.config, {mode: 'CREATE_PAUSED', acknowledgeSpendLimits: true}, edits);
  return x;
}

test('packaged defaults cannot create or spend; identity, geography and money are blank', () => {
  const box = {};
  vm.createContext(box);
  vm.runInContext(source + '\nglobalThis.c = CONFIG;', box);
  assert.equal(box.c.mode, 'PLAN');
  assert.equal(box.c.dailyBudget, null);
  assert.equal(box.c.countryCode, '');
  assert.equal(box.c.expectedCustomerId, '');
  assert.equal(box.c.expectedCurrency, '');
  assert.equal(box.c.acknowledgeSpendLimits, false);
});
test('PLAN performs reads only and exposes spend arithmetic', () => {
  const {h, state} = harness(); h.main();
  assert.equal(state.mutations.length, 0);
  assert.match(state.logs.join('\n'), /"conservativeExposureBeforeTaxes": 140/);
  assert.match(state.logs.join('\n'), /NOT a lifetime cap/);
});
test('campaign is paused; all six dependent operations are submitted atomically', () => {
  const {h, state} = create(); h.main();
  assert.equal(state.mutations.length, 1);
  const {operations: ops, options} = state.mutations[0];
  assert.deepEqual(options, {apiVersion: 'v25', partialFailure: false});
  assert.equal(ops.length, 6);
  const budget = ops[0].campaignBudgetOperation.create;
  const campaign = ops[1].campaignOperation.create;
  assert.equal(budget.amountMicros, '5000000');
  assert.equal(budget.explicitlyShared, false);
  assert.equal(campaign.campaignBudget, budget.resourceName);
  assert.equal(campaign.status, 'PAUSED');
  assert.equal(campaign.advertisingChannelType, 'MULTI_CHANNEL');
  assert.equal(campaign.advertisingChannelSubType, 'APP_CAMPAIGN');
  assert.equal(campaign.appCampaignSetting.appId, 'app.soulbuddy.soulbuddy');
  assert.equal(campaign.appCampaignSetting.appStore, 'GOOGLE_APP_STORE');
  assert.equal(campaign.appCampaignSetting.biddingStrategyGoalType,
    'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST');
  assert.deepEqual(campaign.maximizeConversions, {});
  assert.equal(campaign.targetCpa, undefined);
  assert.deepEqual(campaign.selectiveOptimization.conversionActions, [CONVERSION]);
  assert.equal(campaign.startDateTime, '2026-09-17 00:00:00');
  assert.equal(campaign.endDateTime, '2026-09-30 23:59:59');
  assert.equal(campaign.geoTargetTypeSetting.positiveGeoTargetType, 'PRESENCE');
  assert.equal(ops[2].campaignCriterionOperation.create.campaign, campaign.resourceName);
  assert.equal(ops[3].campaignCriterionOperation.create.language.languageConstant, 'languageConstants/1000');
  assert.equal(ops[4].adGroupOperation.create.type, undefined);
  assert.equal(ops[5].adGroupAdOperation.create.adGroup, ops[4].adGroupOperation.create.resourceName);
  assert.equal(ops[5].adGroupAdOperation.create.ad.appAd.headlines.length, 5);
  assert.equal(ops[5].adGroupAdOperation.create.ad.appAd.descriptions.length, 5);
  assert.doesNotMatch(JSON.stringify(ops), /userList|audience|customAudience|keyword|customerMatch/);
});
test('conversion query requires correct package, source, enabled and primary status', () => {
  const {h, state} = harness(); h.main();
  const query = state.queries.find(q => q.includes('FROM conversion_action '));
  for (const part of ["'GOOGLE_PLAY_DOWNLOAD'", "'ENABLED'", 'primary_for_goal = TRUE',
    "app_id = 'app.soulbuddy.soulbuddy'"]) assert.ok(query.includes(part));
});
test('target CPI opt-in uses targetCpa and never silently increases budget', () => {
  const {h, state} = create({}, {targetCpi: 0.5}); h.main();
  const ops = state.mutations[0].operations;
  assert.deepEqual(ops[1].campaignOperation.create.targetCpa, {targetCpaMicros: '500000'});
  assert.equal(ops[1].campaignOperation.create.maximizeConversions, undefined);
  assert.equal(ops[0].campaignBudgetOperation.create.amountMicros, '5000000');
  assert.match(state.logs.join('\n'), /recommended 50 x target CPI/);
});
test('preview is identified accurately and never reported as persisted', () => {
  const {h, state} = create({preview: true}); h.main();
  assert.match(state.logs.join('\n'), /No campaign was persisted/);
  assert.doesNotMatch(state.logs.join('\n'), /CREATED PAUSED/);
});
for (const status of ['PAUSED', 'ENABLED', 'REMOVED']) {
  test('existing ' + status + ' campaign is never duplicated, updated or enabled', () => {
    const {h, state} = create({existing: [{campaign: {resourceName: 'customers/1234567890/campaigns/90', status}}]});
    h.main(); assert.equal(state.mutations.length, 0);
    assert.equal(state.queries.length, 1);
  });
}
for (const [label, edits] of [
  ['wrong account', {expectedCustomerId: '9999999999'}],
  ['wrong currency', {expectedCurrency: 'NGN'}],
  ['missing country', {countryCode: ''}], ['invalid country', {countryCode: 'NG,US'}],
  ['missing budget', {dailyBudget: null}], ['zero budget', {dailyBudget: 0}],
  ['negative budget', {dailyBudget: -1}], ['string budget', {dailyBudget: '5'}],
  ['infinite budget', {dailyBudget: Infinity}], ['NaN budget', {dailyBudget: NaN}],
  ['excess precision', {dailyBudget: 0.0000001}], ['unsafe budget', {dailyBudget: 1e12}],
  ['invalid mode', {mode: 'ENABLE'}], ['no spend consent', {acknowledgeSpendLimits: false}],
  ['zero days', {testDays: 0}], ['fractional days', {testDays: 1.5}], ['unbounded days', {testDays: 31}],
  ['past date', {startDate: '2026-09-16'}], ['invalid date', {startDate: '2026-02-30'}],
  ['overflow date', {startDate: '9999-12-31'}], ['zero CPI', {targetCpi: 0}],
  ['infinite CPI', {targetCpi: Infinity}], ['invalid key', {campaignKey: 'x\ny'}],
  ['URL instead of asset', {imageAssetResources: ['https://example.test/image.png']}],
  ['cross-account asset', {imageAssetResources: ['customers/9999999999/assets/42']}],
  ['malformed conversion', {installConversionResource: '77'}],
  ['overlong headline', {headlines: ['a'.repeat(31), 'Faithful habits']}],
  ['overlong description', {descriptions: ['a'.repeat(91), 'Faithful daily habits.']}],
  ['duplicate text', {headlines: ['Pray', 'Pray']}],
  ['multibyte text fails safe', {headlines: ['Pray today', 'Pray 🙏']}]
]) {
  test(label + ' fails without mutation', () => {
    const {h, state} = create({}, edits);
    assert.throws(() => h.main()); assert.equal(state.mutations.length, 0);
  });
}
test('missing conversion still permits read-only planning', () => {
  const {h, state} = harness({conversions: []}); h.main();
  assert.equal(state.mutations.length, 0); assert.match(state.logs.join('\n'), /MISSING/);
});
test('missing conversion blocks creation, including budget creation', () => {
  const {h, state} = create({conversions: []});
  assert.throws(() => h.main(), /No unique enabled primary/); assert.equal(state.mutations.length, 0);
});
test('ambiguous conversions require exact selection, never a guessed goal', () => {
  const rows = [77, 88].map(id => ({conversionAction: {resourceName: 'customers/' + CUSTOMER + '/conversionActions/' + id}}));
  const x = create({conversions: rows});
  assert.throws(() => x.h.main(), /No unique/); assert.equal(x.state.mutations.length, 0);
  x.config.installConversionResource = CONVERSION; x.h.main();
  assert.equal(x.state.mutations.length, 1);
});
test('explicit conversion must match discovered package-specific candidates', () => {
  const {h, state} = create({}, {installConversionResource: 'customers/1234567890/conversionActions/999'});
  assert.throws(() => h.main(), /Selected conversion/); assert.equal(state.mutations.length, 0);
});
test('missing country never falls back to worldwide', () => {
  const {h, state} = create({countries: []});
  assert.throws(() => h.main(), /resolve enabled country/); assert.equal(state.mutations.length, 0);
});
test('optional image/video asset references are verified and attached', () => {
  const image = 'customers/' + CUSTOMER + '/assets/100';
  const video = 'customers/' + CUSTOMER + '/assets/101';
  const {h, state} = create({assets: [{asset: {resourceName: image, type: 'IMAGE'}}]},
    {imageAssetResources: [image]});
  h.main();
  assert.deepEqual(state.mutations[0].operations[5].adGroupAdOperation.create.ad.appAd.images, [{asset: image}]);
  const x = create({assets: [{asset: {resourceName: video, type: 'YOUTUBE_VIDEO'}}]},
    {videoAssetResources: [video]}); x.h.main();
  assert.deepEqual(x.state.mutations[0].operations[5].adGroupAdOperation.create.ad.appAd.youtubeVideos, [{asset: video}]);
});
test('missing or mistyped assets fail closed', () => {
  const {h, state} = create({assets: []}, {imageAssetResources: ['customers/' + CUSTOMER + '/assets/100']});
  assert.throws(() => h.main(), /asset is missing/); assert.equal(state.mutations.length, 0);
});
test('API validation failure is surfaced and never reported as success', () => {
  const {h, state} = create({apiFailure: true});
  assert.throws(() => h.main(), /Atomic request failed/);
  assert.equal(state.mutations[0].options.partialFailure, false);
  assert.doesNotMatch(state.logs.join('\n'), /CREATED PAUSED/);
});
test('unexpected API response requires inspection rather than blind retry', () => {
  const {h} = create({shortResponse: true}); assert.throws(() => h.main(), /Inspect Google Ads before retrying/);
});
test('transport errors do not trigger a second mutation', () => {
  const {h, state} = create({transportError: true});
  assert.throws(() => h.main(), /transport failure/); assert.equal(state.mutations.length, 1);
});
test('inclusive dates cover leap year, month/year rollover and single-day window', () => {
  const {h, config} = harness();
  assert.equal(h.addDays('2028-02-28', 1), '2028-02-29');
  assert.equal(h.addDays('2026-12-31', 1), '2027-01-01');
  config.testDays = 1; assert.equal(h.validateConfig(config, context).end, context.today);
  config.startDate = '2027-12-25'; config.testDays = 14;
  assert.equal(h.validateConfig(config, context).end, '2028-01-07');
});
test('money uses exact micros for supported decimal inputs', () => {
  const {h} = harness();
  assert.equal(h.toMicros(0.29), 290000); assert.equal(h.toMicros(0.000001), 1);
  assert.equal(h.toMicros(5000), 5000000000);
});
test('GAQL escapes quotes/backslashes and permits safe names', () => {
  const {h} = harness();
  assert.equal(h.gaqlString("SoulBuddy's\\test"), "'SoulBuddy\\'s\\\\test'");
});
