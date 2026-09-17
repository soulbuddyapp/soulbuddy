'use strict';
// Offline contract tests: the fake backend models persisted IDs and Preview's lack
// of persistence. It is NOT a substitute for Google's API/account validation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const ROOT = __dirname;
const SOURCE = fs.readFileSync(path.join(ROOT, 'setup-google-ads.js'), 'utf8');
const OWNER = 'customers/7904459880';
const APP = 'app.soulbuddy.soulbuddy';
const MARKER = 'const EMBEDDED_IMAGES = []; // @SOULBUDDY_IMAGES@';
const clone = value => JSON.parse(JSON.stringify(value));
const conversion = (id = '77', overrides = {}) => ({resourceName: OWNER + '/conversionActions/' + id,
  type: 'GOOGLE_PLAY_DOWNLOAD', appId: APP, status: 'ENABLED', primaryForGoal: true, ...overrides});
function fakeImages() {
  return [['landscape', 628], ['square', 1200], ['portrait', 1500]].map(([shape, height], i) => {
    const bytes = Buffer.from([255, 216, i, 255, 217]); // integrity-only fixture, not a decoded JPEG
    const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
    return {name: 'SoulBuddy transformation ' + shape + ' ' + sha256.slice(0, 16), width: 1200, height,
      bytes: bytes.length, sha256, data: bytes.toString('base64')};
  });
}
function harness(options = {}, store = {conversions: clone(options.conversions || []), campaigns: []}) {
  const state = {calls: [], queries: [], logs: [], resourceReads: 0, store};
  const preview = options.preview === true;
  const box = {console: {log: value => state.logs.push(String(value))},
    Utilities: {DigestAlgorithm: {SHA_256: 'sha256'},
      base64Decode: s => Array.from(Buffer.from(s, 'base64')),
      computeDigest: (alg, bytes) => Array.from(crypto.createHash(alg).update(Buffer.from(bytes)).digest()),
      formatDate: (_date, zone, fmt) => {
        assert.equal(zone, options.timezone || 'Africa/Lagos'); assert.equal(fmt, 'yyyy-MM-dd');
        return options.today || '2026-09-17';
      }},
    AdsApp: {
      getExecutionInfo: () => ({isPreview: () => preview}),
      currentAccount: () => ({getCustomerId: () => options.customerId || '790-445-9880',
        getCurrencyCode: () => options.currency || 'USD', getTimeZone: () => options.timezone || 'Africa/Lagos'}),
      search: (query, settings) => {
        assert.equal(settings.apiVersion, 'v25'); state.queries.push(query);
        let rows;
        if (query.includes('FROM campaign ')) rows = query.includes('campaign.name =')
          ? (options.named || store.campaigns).map(campaign => ({campaign}))
          : (options.active || []).map(campaign => ({campaign}));
        else if (query.includes('FROM customer')) rows = [{customer: {id: '7904459880', manager: !!options.manager,
          conversionTrackingSetting: {googleAdsConversionCustomer: options.owner === undefined ? OWNER : options.owner}}}];
        else if (query.includes('FROM geo_target_constant')) rows = options.countries || [{geoTargetConstant: {
          resourceName: 'geoTargetConstants/2566', name: 'Nigeria'}}];
        else if (query.includes('FROM language_constant')) rows = options.languages || [{languageConstant: {
          resourceName: 'languageConstants/1000'}}];
        else if (query.includes('FROM conversion_action')) rows = store.conversions.map(conversionAction => ({conversionAction}));
        else if (query.includes('FROM asset ')) rows = (options.assets || []).map(asset => ({asset}));
        else throw new Error('Unexpected query: ' + query);
        let i = 0; return {hasNext: () => i < rows.length, next: () => rows[i++]};
      },
      mutateAll: (ops, settings) => {
        assert.deepEqual(clone(settings), {apiVersion: 'v25', partialFailure: false});
        const call = {operations: clone(ops), settings: clone(settings)}; state.calls.push(call);
        if (options.reply) return options.reply(ops, state.calls.length - 1);
        const failures = ops.map(op => {
          if (op.conversionActionOperation && options.failConversion) return 'CONVERSION_REJECTED';
          const campaign = op.campaignOperation && op.campaignOperation.create;
          if (campaign) {
            const refs = campaign.selectiveOptimization?.conversionActions || [];
            if (refs.some(ref => !store.conversions.some(c => c.resourceName === ref)))
              return 'Resource was not found. At campaignOperation.create.selectiveOptimization.conversionActions';
            if (options.failCampaign) return 'CAMPAIGN_REJECTED';
          }
          return '';
        });
        // Enforce per-request atomicity, not a fictional transaction across calls.
        const committed = !preview && failures.every(s => !s);
        return ops.map((op, i) => {
          let resource = OWNER + '/assets/' + (800 + i);
          if (op.conversionActionOperation) {
            resource = OWNER + '/conversionActions/1234567890123456789';
            if (committed) store.conversions.push({...clone(op.conversionActionOperation.create), resourceName: resource});
            if (options.conversionResource !== undefined) resource = options.conversionResource;
          }
          if (op.campaignOperation) {
            resource = OWNER + '/campaigns/9000';
            if (committed) store.campaigns.push({...clone(op.campaignOperation.create), resourceName: resource});
            if (options.campaignResource !== undefined) resource = options.campaignResource;
          }
          return {isSuccessful: () => !failures[i], getErrorMessages: () => failures[i] ? [failures[i]] : [],
            getResourceName: () => {
              state.resourceReads++;
              if (preview) throw new Error('Preview has no persisted ID');
              if (options.resourceThrows) throw new Error('Unreadable result resource');
              return resource;
            }};
        });
      }
    }};
  const images = options.images === undefined ? fakeImages() : options.images;
  let code = options.code || SOURCE.replace(MARKER, 'const EMBEDDED_IMAGES = ' + JSON.stringify(images) + ';');
  if (options.diagnostic) code = code.replace('PREVIEW_CHECK_ONLY = false;', 'PREVIEW_CHECK_ONLY = true;');
  vm.createContext(box);
  vm.runInContext(code + '\nglobalThis.h = {main, setupPilot, makePlan, planConversion, buildOperations, ' +
    'buildConversionOperation, submitBatch, persistedResource, requireSuccess, diagnosticText, printOutcome, ' +
    'HEADLINES, DESCRIPTIONS, validateText, compareResourceIds, addDays, toMicros, quoted};', box);
  return {state, h: box.h, box};
}
function run(options = {}, store) {const x = harness(options, store); x.h.main(); return x;}
function creations(x, key) {return x.state.calls.flatMap(c => c.operations).filter(op => op[key]).map(op => op[key].create);}
function text(x) {return x.state.logs.join('\n');}

test('fresh live setup creates conversion first and binds its returned REAL ID', () => {
  const x = run();
  assert.equal(x.state.calls.length, 2);
  assert.deepEqual(Object.keys(x.state.calls[0].operations[0]), ['conversionActionOperation']);
  assert.equal(x.state.calls[0].operations.length, 1);
  assert.equal(x.state.calls[1].operations.length, 9);
  const action = creations(x, 'conversionActionOperation')[0];
  assert.equal(action.resourceName, undefined); // Google allocates the standalone ID
  assert.equal(action.type, 'GOOGLE_PLAY_DOWNLOAD'); assert.equal(action.category, 'DOWNLOAD');
  assert.equal(action.appId, APP); assert.equal(action.primaryForGoal, true);
  assert.deepEqual(action.valueSettings, {defaultValue: 0, defaultCurrencyCode: 'USD', alwaysUseDefaultValue: true});
  const campaign = creations(x, 'campaignOperation')[0];
  assert.deepEqual(campaign.selectiveOptimization.conversionActions, [x.state.store.conversions[0].resourceName]);
  assert.equal(x.state.store.conversions.length, 1); assert.equal(x.state.store.campaigns.length, 1);
  assert.match(text(x), /CREATED PAUSED/);
});
test('Preview validates structure but never reads a simulated resource ID', () => {
  const x = run({preview: true});
  assert.equal(x.state.calls.length, 2); assert.equal(x.state.resourceReads, 0);
  assert.equal(x.state.store.conversions.length, 0); assert.equal(x.state.store.campaigns.length, 0);
  assert.equal(creations(x, 'campaignOperation')[0].selectiveOptimization, undefined);
  assert.match(text(x), /PREVIEW STRUCTURE PASSED/);
  assert.match(text(x), /binding remains unvalidated until Run/);
  assert.doesNotMatch(text(x), /CREATED PAUSED/);
});
for (const preview of [true, false]) {
  test('existing conversion is bound directly in ' + (preview ? 'Preview' : 'Run'), () => {
    const x = run({preview, conversions: [conversion()]});
    assert.equal(x.state.calls.length, 1);
    assert.equal(creations(x, 'conversionActionOperation').length, 0);
    assert.deepEqual(creations(x, 'campaignOperation')[0].selectiveOptimization.conversionActions, [conversion().resourceName]);
    if (preview) assert.match(text(x), /PREVIEW PASSED WITH EXISTING INSTALL GOAL/);
  });
}
test('original failing dependency is reproduced by the regression backend', () => {
  const old = fs.readFileSync(path.join(ROOT, 'fixtures', 'temporary-conversion-request.json'), 'utf8');
  const x = harness({preview: true});
  const results = x.box.AdsApp.mutateAll(JSON.parse(old), {apiVersion: 'v25', partialFailure: false});
  assert.equal(results[0].isSuccessful(), true);
  assert.equal(results[1].isSuccessful(), false);
  assert.match(results[1].getErrorMessages()[0], /selectiveOptimization.conversionActions/);
});
test('all other campaign settings and media are unchanged', () => {
  const x = run(); const c = creations(x, 'campaignOperation')[0];
  assert.equal(c.status, 'PAUSED'); assert.equal(c.advertisingChannelType, 'MULTI_CHANNEL');
  assert.equal(c.advertisingChannelSubType, 'APP_CAMPAIGN');
  assert.deepEqual(c.appCampaignSetting, {appId: APP, appStore: 'GOOGLE_APP_STORE',
    biddingStrategyGoalType: 'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST'});
  assert.deepEqual(c.maximizeConversions, {}); assert.equal(c.targetCpa, undefined);
  assert.equal(c.startDateTime, '2026-09-17 00:00:00'); assert.equal(c.endDateTime, '2026-09-30 23:59:59');
  assert.deepEqual(c.geoTargetTypeSetting, {positiveGeoTargetType: 'PRESENCE', negativeGeoTargetType: 'PRESENCE'});
  const budget = creations(x, 'campaignBudgetOperation')[0];
  assert.equal(budget.amountMicros, '3000000'); assert.equal(budget.explicitlyShared, false);
  const criteria = creations(x, 'campaignCriterionOperation');
  assert.deepEqual(criteria.map(item => item.campaign), [c.resourceName, c.resourceName]);
  assert.equal(criteria[0].location.geoTargetConstant, 'geoTargetConstants/2566');
  assert.equal(criteria[1].language.languageConstant, 'languageConstants/1000');
  const ad = creations(x, 'adGroupAdOperation')[0].ad.appAd;
  assert.equal(ad.headlines.length, 5); assert.equal(ad.descriptions.length, 5); assert.equal(ad.images.length, 3);
  assert.equal(ad.youtubeVideos, undefined);
  assert.deepEqual(ad.images.map(a => a.asset), creations(x, 'assetOperation').map(a => a.resourceName));
  assert.doesNotMatch(JSON.stringify(x.state.calls), /userList|customAudience|customerMatch|keyword|youtubeVideo/);
  for (const call of x.state.calls) for (const op of call.operations) assert.deepEqual(Object.keys(Object.values(op)[0]), ['create']);
});
for (const [currency, amount] of [['USD',3], ['NGN',3000], ['EUR',3], ['GBP',2], ['CAD',4], ['AUD',4]]) {
  test('unchanged ' + currency + ' allowance', () => {
    const x = run({currency}); assert.equal(creations(x,'campaignBudgetOperation')[0].amountMicros,String(amount*1000000));
    assert.match(text(x), new RegExp('"conservativeWindowExposureBeforeTaxes": '+amount*28));
  });
}
test('conversion failure stops before budget, assets or campaign are submitted', () => {
  const x = harness({failConversion:true}); assert.throws(() => x.h.main(), /INSTALL_CONVERSION: atomic request rejected/);
  assert.equal(x.state.calls.length,1); assert.equal(x.state.store.conversions.length,0);
});
test('campaign rejection retains conversion; the next run reuses it', () => {
  const x = harness({failCampaign:true}); assert.throws(() => x.h.main(), /CAMPAIGN_WITH_INSTALL_GOAL: atomic request rejected/);
  assert.equal(x.state.store.conversions.length,1); assert.equal(x.state.store.campaigns.length,0);
  assert.match(text(x), /RETAINED INSTALL CONVERSION/);
  assert.match(text(x), /Earlier successful requests, if any, remain/);
  const y = run({},x.state.store); assert.equal(y.state.calls.length,1);
  assert.equal(creations(y,'conversionActionOperation').length,0);
  assert.equal(y.state.store.conversions.length,1); assert.equal(y.state.store.campaigns.length,1);
  const z=run({},y.state.store); assert.equal(z.state.calls.length,0);
});
for (const result of [OWNER+'/conversionActions/-4', OWNER+'/assets/123', 'customers/9/conversionActions/1', '', null]) {
  test('invalid returned conversion ID blocks all downstream writes: '+String(result), () => {
    const x=harness({conversionResource:result}); assert.throws(()=>x.h.main(),/unexpected conversionActions resource/);
    assert.equal(x.state.calls.length,1); assert.doesNotMatch(text(x),/CREATED PAUSED/);
  });
}
test('unreadable success resource is not retried or called rolled back', () => {
  const x=harness({resourceThrows:true}); assert.throws(()=>x.h.main(),/It may have been saved/);
  assert.equal(x.state.calls.length,1);
});
test('returned campaign resource must belong to the same account', () => {
  const x=harness({campaignResource:'customers/9/campaigns/1'}); assert.throws(()=>x.h.main(),/unexpected campaigns resource/);
  assert.doesNotMatch(text(x),/CREATED PAUSED/);
});
for (const preview of [true,false]) {
  test('temporary selection cannot cross the mutation boundary, preview='+preview, () => {
    const x=harness({preview}); assert.throws(()=>x.h.submitBatch([{campaignOperation:{create:{status:'PAUSED',
      selectiveOptimization:{conversionActions:[OWNER+'/conversionActions/-4']}}}}]),/real install-conversion ID/);
    assert.equal(x.state.calls.length,0);
  });
}
test('a live unbound campaign is forbidden, independent of setup path', () => {
  const x=harness(); assert.throws(()=>x.h.submitBatch([{campaignOperation:{create:{status:'PAUSED'}}}]),/real install-conversion ID/);
  assert.equal(x.state.calls.length,0);
});
test('enabled campaign cannot cross the mutation boundary', () => {
  const x=harness({preview:true}); assert.throws(()=>x.h.submitBatch([{campaignOperation:{create:{status:'ENABLED'}}}]),/never enable/);
  assert.equal(x.state.calls.length,0);
});
test('diagnostic Run is a no-op before reads or writes', () => {
  const x=run({diagnostic:true}); assert.equal(x.state.calls.length,0); assert.equal(x.state.queries.length,0);
  assert.match(text(x), /Click PREVIEW, not Run/);
  assert.throws(()=>x.h.submitBatch([]),/forbidden outside Google Preview/);
});
test('diagnostic Preview uses same two stages, no optional-field probe loops', () => {
  const x=run({diagnostic:true,preview:true}); assert.equal(x.state.calls.length,2);
  assert.match(text(x),/DIAGNOSTIC END/); assert.match(text(x),/binding remains unvalidated/);
  assert.doesNotMatch(text(x),/Use Run on|WITHOUT_GEO|WITHOUT_BOTH/);
});
for (const [label, opts] of [
  ['wrong account',{customerId:'123-456-7890'}], ['currency',{currency:'JPY'}], ['prototype currency',{currency:'toString'}],
  ['manager',{manager:true}], ['missing owner',{owner:''}], ['foreign owner',{owner:'customers/123'}],
  ['country lookup',{countries:[]}], ['language lookup',{languages:[]}], ['date',{today:'2026-02-30'}],
  ['overflow date',{today:'9999-12-31'}], ['unbundled source',{images:[]}],
  ['secondary',{conversions:[conversion('77',{primaryForGoal:false})]}],
  ['hidden',{conversions:[conversion('77',{status:'HIDDEN'})]}],
  ['removed',{conversions:[conversion('77',{status:'REMOVED'})]}],
  ['wrong package',{conversions:[conversion('77',{appId:'another.app'})]}],
  ['wrong conversion type',{conversions:[conversion('77',{type:'WEBPAGE'})]}]
]) {
  test(label+' fails before any mutation',()=>{const x=harness(opts);assert.throws(()=>x.h.main());assert.equal(x.state.calls.length,0);});
}
for (const status of ['PAUSED','ENABLED','REMOVED']) {
  test('existing '+status+' same-named campaign is not modified',()=>{
    const x=run({named:[{status}]});assert.equal(x.state.calls.length,0);
  });
}
test('another active SoulBuddy campaign blocks duplication',()=>{const x=run({active:[{status:'PAUSED'}]});assert.equal(x.state.calls.length,0);});
test('multiple eligible install conversions select one deterministically',()=>{
  const x=run({conversions:[conversion('100'),conversion('9'),conversion('77')]});
  assert.deepEqual(creations(x,'campaignOperation')[0].selectiveOptimization.conversionActions,[OWNER+'/conversionActions/9']);
});
test('existing eligible manager-owned conversion is reused without write',()=>{
  const ref='customers/123/conversionActions/7';
  const x=run({owner:'customers/123',conversions:[conversion('7',{resourceName:ref})]});
  assert.equal(x.state.calls.length,1);assert.deepEqual(creations(x,'campaignOperation')[0].selectiveOptimization.conversionActions,[ref]);
});
test('matching images are reused with no duplicate uploads',()=>{
  const assets=fakeImages().map((im,i)=>({name:im.name,type:'IMAGE',resourceName:OWNER+'/assets/'+(10+i),
    imageAsset:{fullSize:{widthPixels:im.width,heightPixels:im.height}}}));
  const x=run({assets});assert.equal(creations(x,'assetOperation').length,0);
});
for (const defect of ['type','owner','width']) {
  test('invalid reused image '+defect+' blocks conversion creation too',()=>{
    const im=fakeImages()[0];const a={name:im.name,type:'IMAGE',resourceName:OWNER+'/assets/1',imageAsset:{fullSize:{widthPixels:1200,heightPixels:628}}};
    if(defect==='type')a.type='YOUTUBE_VIDEO';if(defect==='owner')a.resourceName='customers/9/assets/1';if(defect==='width')a.imageAsset.fullSize.widthPixels=1;
    const x=harness({assets:[a]});assert.throws(()=>x.h.main());assert.equal(x.state.calls.length,0);
  });
}
for (const defect of ['checksum','base64','bytes','name','dimensions','missing-ratio']) {
  test('corrupt image '+defect+' fails closed',()=>{
    const images=fakeImages();const im=images[0];
    if(defect==='checksum')im.sha256='0'.repeat(64);if(defect==='base64')im.data='broken!';
    if(defect==='bytes')im.bytes++;if(defect==='name')im.name='wrong';if(defect==='dimensions')im.width=123;
    if(defect==='missing-ratio')im.height=1200;
    const x=harness({images});assert.throws(()=>x.h.main());assert.equal(x.state.calls.length,0);
  });
}
for (const defect of ['throw','short','null','missing-method','errors-throw']) {
  test('ambiguous '+defect+' response never triggers a retry or downstream request',()=>{
    const x=harness({reply:ops=>{
      if(defect==='throw')throw new Error('transport timeout');if(defect==='short')return [];if(defect==='null')return null;
      return ops.map(()=>defect==='missing-method'?{}:{isSuccessful:()=>false,getErrorMessages:()=>{throw new Error('unreadable');}});
    }});
    assert.throws(()=>x.h.main(),/ambiguous Google Ads response/);assert.equal(x.state.calls.length,1);
    assert.match(text(x),/DIAGNOSTIC END/);assert.doesNotMatch(text(x),/CREATED PAUSED/);
  });
}
test('generic backend errors are preserved, not replaced with invented codes',()=>{
  const x=harness({reply:ops=>ops.map(()=>({isSuccessful:()=>false,getErrorMessages:()=>['An error has occurred. Please try again later.']}))});
  assert.throws(()=>x.h.main());assert.match(text(x),/INSTALL_CONVERSION ERROR: An error has occurred/);
});
test('diagnostic messages redact long data and bound output',()=>{
  const {h}=harness();assert.equal(h.diagnosticText('A'.repeat(400)),'[LONG_DATA_REDACTED]');
  assert.ok(h.diagnosticText('long message '.repeat(1000)).length<6100);
  const x=harness({reply:()=>[{isSuccessful:()=>false,getErrorMessages:()=>Array(99).fill('error')}]});
  assert.equal(x.h.submitBatch([{conversionActionOperation:{create:{}}}]).rows[0].errors.length,6);
});
test('dates, large IDs, text, currency micros and query escaping remain valid',()=>{
  const x=run({today:'2028-02-28',timezone:'America/Los_Angeles'});
  assert.equal(creations(x,'campaignOperation')[0].endDateTime,'2028-03-12 23:59:59');
  const h=x.h;assert.equal(h.addDays('2026-12-31',1),'2027-01-01');assert.equal(h.toMicros(3000),3000000000);
  assert.equal(h.compareResourceIds('x/9999999999999999999','x/10000000000000000000'),-1);
  h.validateText(h.HEADLINES,30);h.validateText(h.DESCRIPTIONS,90);assert.equal(h.quoted("a'b\\c"),"'a\\'b\\\\c'");
});
test('real distributed scripts have intact images and differ only by Preview-only flag',()=>{
  const normal=fs.readFileSync(path.join(ROOT,'ready','SoulBuddy-Ready-to-Run.js'),'utf8');
  const diag=fs.readFileSync(path.join(ROOT,'ready','SoulBuddy-Preview-Check.js'),'utf8');
  assert.equal(normal.replace('PREVIEW_CHECK_ONLY = false;','PREVIEW_CHECK_ONLY = true;'),diag);
  for(const code of [normal,diag]) {
    const x=run({code,preview:true});assert.equal(creations(x,'assetOperation').length,3);
    for(const a of creations(x,'assetOperation'))assert.ok(Buffer.from(a.imageAsset.data,'base64').length>10000);
    assert.ok(Buffer.byteLength(code)<1024*1024);assert.doesNotMatch(code,/UrlFetchApp|DriveApp|MailApp|eval\(|new Function\(/);
  }
});
