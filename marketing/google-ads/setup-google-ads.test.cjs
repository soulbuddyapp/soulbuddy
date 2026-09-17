'use strict';
// Offline lifecycle contract tests. The fake backend reproduces the supplied
// failed temporary-parent path; it is NOT live API acceptance or policy validation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = __dirname;
const source = fs.readFileSync(path.join(root, 'setup-google-ads.js'), 'utf8');
const OWNER = 'customers/7904459880', APP = 'app.soulbuddy.soulbuddy';
const clone = x => JSON.parse(JSON.stringify(x));
const targets = {country: 'geoTargetConstants/2566', language: 'languageConstants/1000'};
function imageFixtures() {
  return [['landscape',628],['square',1200],['portrait',1500]].map(([shape,height],i) => {
    const data = Buffer.from([255,216,i,255,217]); // checksum fixture; real bundle tested separately
    const sha256 = crypto.createHash('sha256').update(data).digest('hex');
    return {name:'SoulBuddy transformation '+shape+' '+sha256.slice(0,16),width:1200,height,
      bytes:data.length,sha256,data:data.toString('base64')};
  });
}
function newStore() {return {conversions:[],budgets:[],campaigns:[],criteria:[],assets:[],groups:[],ads:[],next:100};}
function conversion(id='77', extra={}) {return {resourceName:OWNER+'/conversionActions/'+id,type:'GOOGLE_PLAY_DOWNLOAD',
  appId:APP,status:'ENABLED',primaryForGoal:true,...extra};}
function harness(options={}, store=newStore()) {
  if (options.conversions) store.conversions=clone(options.conversions);
  const state={store,calls:[],queries:[],logs:[],resourceReads:0};
  const preview=options.preview===true;
  const box={console:{log:x=>state.logs.push(String(x))}, Utilities:{
    DigestAlgorithm:{SHA_256:'sha256'},base64Decode:s=>Array.from(Buffer.from(s,'base64')),
    computeDigest:(alg,bytes)=>Array.from(crypto.createHash(alg).update(Buffer.from(bytes)).digest()),
    formatDate:()=>options.today||'2026-09-17'
  }, AdsApp:{
    currentAccount:()=>({getCustomerId:()=>options.customerId||'790-445-9880',
      getCurrencyCode:()=>options.currency||'USD',getTimeZone:()=>options.timezone||'Africa/Lagos'}),
    getExecutionInfo:()=>({isPreview:()=>preview}),
    search:(q,settings)=>{
      assert.equal(settings.apiVersion,'v25');state.queries.push(q);
      if(options.beforeRead) options.beforeRead(q,store);
      let rows=[];
      if(q.includes('FROM campaign ')) {
        if(q.includes('WHERE campaign.resource_name =')) rows=store.campaigns.filter(c=>q.includes("'"+c.resourceName+"'"))
          .map(c=>({campaign:clone(c),campaignBudget:clone(store.budgets.find(b=>b.resourceName===c.campaignBudget))}));
        else if(q.includes('WHERE campaign.name =')) rows=store.campaigns.filter(c=>c.name===box.h.PILOT.name).map(c=>({campaign:clone(c)}));
        else rows=store.campaigns.filter(c=>c.appCampaignSetting?.appId===APP && c.status!=='REMOVED').map(c=>({campaign:clone(c)}));
      } else if(q.includes('FROM customer')) rows=[{customer:{id:'7904459880',manager:!!options.manager,
        conversionTrackingSetting:{googleAdsConversionCustomer:options.owner===undefined?OWNER:options.owner}}}];
      else if(q.includes('FROM geo_target_constant')) rows=options.noCountry?[]:[{geoTargetConstant:{resourceName:targets.country,name:'Nigeria'}}];
      else if(q.includes('FROM language_constant')) rows=options.noLanguage?[]:[{languageConstant:{resourceName:targets.language}}];
      else if(q.includes('FROM conversion_action')) rows=store.conversions.map(c=>({conversionAction:clone(c)}));
      else if(q.includes('FROM asset ')) rows=store.assets.map(a=>({asset:clone(a)}));
      else if(q.includes('FROM campaign_criterion')) rows=store.criteria.filter(c=>q.includes("'"+c.campaign+"'") &&
        c.status!=='REMOVED' && !(options.hideLanguage && c.type==='LANGUAGE')).map(c=>({campaignCriterion:clone(c)}));
      else if(q.includes('FROM ad_group ')) rows=store.groups.filter(g=>q.includes("'"+g.campaign+"'") && g.status!=='REMOVED').map(g=>({adGroup:clone(g)}));
      else if(q.includes('FROM ad_group_ad')) rows=store.ads.filter(a=>q.includes("'"+a.adGroup+"'") && a.status!=='REMOVED').map(a=>({adGroupAd:clone(a)}));
      else throw new Error('Unexpected query: '+q);
      let i=0;return {hasNext:()=>i<rows.length,next:()=>rows[i++]};
    },
    mutateAll:(ops,settings)=>{
      assert.deepEqual(clone(settings),{apiVersion:'v25',partialFailure:false});
      state.calls.push(clone(ops));
      if(options.reply) return options.reply(ops,state.calls.length-1);
      const failures=ops.map(op=>{
        const kind=Object.keys(op)[0],c=op[kind].create;
        if(options.failKind===kind) return 'SIMULATED_'+kind+'_REJECTION';
        if(kind==='campaignOperation') {
          if((c.selectiveOptimization?.conversionActions||[]).some(r=>!store.conversions.some(a=>a.resourceName===r)))
            return 'Resource was not found. At campaignOperation.create.selectiveOptimization.conversionActions';
        }
        if(kind==='campaignCriterionOperation') {
          if(c.resourceName || !store.campaigns.some(p=>p.resourceName===c.campaign))
            return "The field's contents don't match another field that represents the same data. At campaignCriterionOperation.create.resourceName";
        }
        return '';
      });
      const refs=new Map(), entries=[];
      const collection={conversionActionOperation:'conversionActions',campaignBudgetOperation:'campaignBudgets',
        campaignOperation:'campaigns',assetOperation:'assets',adGroupOperation:'adGroups',adGroupAdOperation:'adGroupAds',
        campaignCriterionOperation:'campaignCriteria'};
      for(const op of ops) {
        const kind=Object.keys(op)[0],c=clone(op[kind].create);
        const resource=OWNER+'/'+collection[kind]+'/'+store.next++;
        if(c.resourceName) refs.set(c.resourceName,resource);
        const resolve=x=>typeof x==='string'?(refs.get(x)||x):Array.isArray(x)?x.map(resolve):
          x&&typeof x==='object'?Object.fromEntries(Object.entries(x).map(([k,v])=>[k,resolve(v)])):x;
        const saved=resolve(c);saved.resourceName=resource;
        if(kind==='campaignOperation') saved.biddingStrategyType='MAXIMIZE_CONVERSIONS';
        if(kind==='campaignCriterionOperation') {saved.status='ENABLED';saved.type=c.location?'LOCATION':'LANGUAGE';}
        if(kind==='adGroupAdOperation') saved.ad.type='APP_AD';
        if(kind==='assetOperation') {
          const image=box.h.EMBEDDED_IMAGES.find(i=>i.name===c.name);
          saved.imageAsset={fullSize:{widthPixels:String(image.width),heightPixels:String(image.height)}};
        }
        entries.push({kind,saved,resource});
      }
      if(!preview && failures.every(x=>!x)) {
        const tables={conversionActionOperation:'conversions',campaignBudgetOperation:'budgets',campaignOperation:'campaigns',
          campaignCriterionOperation:'criteria',assetOperation:'assets',adGroupOperation:'groups',adGroupAdOperation:'ads'};
        for(const e of entries) store[tables[e.kind]].push(e.saved);
      }
      return entries.map((e,i)=>({isSuccessful:()=>!failures[i],getErrorMessages:()=>failures[i]?[failures[i]]:[],
        getResourceName:()=>{
          state.resourceReads++;if(preview)throw new Error('Preview does not persist IDs');
          if(options.badResourceKind===e.kind) return options.badResource;
          if(options.unreadableKind===e.kind)throw new Error('unreadable resource');
          return e.resource;
        }}));
    }
  }};
  let code=options.code||source.replace('const EMBEDDED_IMAGES = []; // @SOULBUDDY_IMAGES@',
    'const EMBEDDED_IMAGES = '+JSON.stringify(options.images||imageFixtures())+';');
  if(options.diagnostic)code=code.replace('PREVIEW_CHECK_ONLY = false;','PREVIEW_CHECK_ONLY = true;');
  vm.createContext(box);
  vm.runInContext(code+'\nglobalThis.h={main,PILOT,EMBEDDED_IMAGES,HEADLINES,DESCRIPTIONS,buildParentOperations,'+
    'buildTargetingOperations,buildCreativeOperations,submitBatch,inspectPilot,inspectTargeting,validateTargetingReferences,'+
    'planConversion,makePlan,persistedResource,validateText,validateImages,diagnosticText,quoted,addDays,toMicros};',box);
  return {h:box.h,box,state};
}
function run(options,store){const x=harness(options,store);x.h.main();return x;}
const log=x=>x.state.logs.join('\n');
const creations=(x,kind)=>x.state.calls.flatMap(c=>c).filter(o=>o[kind]).map(o=>o[kind].create);
function pausedShell() {
  const x=harness({failKind:'campaignCriterionOperation'});assert.throws(()=>x.h.main(),/atomic request rejected/);
  return x.state.store;
}

test('fresh Run persists conversion and paused parent before targeting plus creative',()=>{
  const x=run();assert.equal(x.state.calls.length,3);
  assert.deepEqual(x.state.calls[0].map(o=>Object.keys(o)[0]),['conversionActionOperation']);
  assert.deepEqual(x.state.calls[1].map(o=>Object.keys(o)[0]),['campaignBudgetOperation','campaignOperation']);
  assert.equal(x.state.calls[2].length,7);
  const parent=x.state.store.campaigns[0];
  for(const c of creations(x,'campaignCriterionOperation')) {
    assert.equal(c.campaign,parent.resourceName);assert.match(c.campaign,/campaigns\/\d+$/);
    assert.equal(c.resourceName,undefined);assert.equal(c.criterionId,undefined);assert.equal(c.negative,false);
  }
  assert.equal(parent.status,'PAUSED');assert.equal(x.state.store.criteria.length,2);assert.equal(x.state.store.ads.length,1);
  assert.deepEqual(parent.selectiveOptimization.conversionActions,[x.state.store.conversions[0].resourceName]);
  assert.match(log(x),/SETUP COMPLETE - PAUSED/);assert.match(log(x),/VERIFIED: Nigeria, English/);
  assert.equal(creations(x,'assetOperation').length,3);
  assert.doesNotMatch(JSON.stringify(x.state.calls),/"update"|"remove"|youtubeVideo|customerMatch|customAudience/);
});
test('fresh Preview explicitly defers targeting instead of fabricating resource IDs',()=>{
  const x=run({preview:true});assert.equal(x.state.calls.length,2);assert.equal(x.state.resourceReads,0);
  assert.equal(creations(x,'campaignCriterionOperation').length,0);assert.equal(x.state.store.campaigns.length,0);
  assert.equal(x.state.store.conversions.length,0);assert.equal(x.state.store.assets.length,0);
  assert.match(log(x),/TARGETING: DEFERRED, NOT VALIDATED BY GOOGLE/);
  assert.match(log(x),/PREVIEW PARTIAL CHECK PASSED/);assert.doesNotMatch(log(x),/SETUP COMPLETE/);
  assert.equal(creations(x,'campaignOperation')[0].selectiveOptimization,undefined);
});
test('existing conversion keeps fresh Preview binding, but targeting remains deferred',()=>{
  const x=run({preview:true,conversions:[conversion()]});assert.equal(x.state.calls.length,1);
  assert.deepEqual(creations(x,'campaignOperation')[0].selectiveOptimization.conversionActions,[conversion().resourceName]);
  assert.equal(creations(x,'campaignCriterionOperation').length,0);
});
test('Preview against a real paused parent tests actual targeting without changing store',()=>{
  const store=pausedShell(),before=clone(store);
  const x=run({preview:true},store);assert.equal(x.state.calls.length,1);
  assert.equal(creations(x,'campaignCriterionOperation').length,2);assert.equal(x.state.resourceReads,0);
  assert.equal(store.criteria.length,0);assert.equal(store.ads.length,0);assert.deepEqual(store.campaigns,before.campaigns);
  assert.match(log(x),/PREVIEW PASSED AGAINST SAVED PAUSED PARENT/);
});
test('diagnostic file refuses Run before any account reads or mutations',()=>{
  const x=run({diagnostic:true});assert.equal(x.state.calls.length,0);assert.equal(x.state.queries.length,0);
  assert.match(log(x),/Click PREVIEW, not Run/);
  assert.throws(()=>x.h.submitBatch([]),/forbidden outside Google Preview/);
});
test('diagnostic Preview also defers unsaved-parent targeting without looped probes',()=>{
  const x=run({diagnostic:true,preview:true});assert.equal(x.state.calls.length,2);
  assert.match(log(x),/DEFERRED/);assert.doesNotMatch(log(x),/Run this unchanged/);
});
for(const named of [false,true])test('observed old criteria path is rejected by fixture backend; explicit names='+named,()=>{
  const x=harness({preview:true});const r=x.box.AdsApp.mutateAll([{campaignCriterionOperation:{create:{
    campaign:OWNER+'/campaigns/-2',...(named?{resourceName:OWNER+'/campaignCriteria/-2~-5'}:{}),
    location:{geoTargetConstant:targets.country}}}}],{apiVersion:'v25',partialFailure:false});
  assert.equal(r[0].isSuccessful(),false);assert.match(r[0].getErrorMessages()[0],/create.resourceName/);
});
for(const ref of [OWNER+'/campaigns/-2','customers/999/campaigns/1','',null])test('target builder rejects unsaved or foreign parent '+ref,()=>{
  assert.throws(()=>harness().h.buildTargetingOperations(ref,targets,[]),/saved positive campaign/);
});
for(const field of ['resourceName','criterionId'])test('old custom '+field+' never reaches mutation',()=>{
  const x=harness({preview:true}),c={campaign:OWNER+'/campaigns/12',negative:false,location:{geoTargetConstant:targets.country}};
  c[field]=field==='resourceName'?OWNER+'/campaignCriteria/12~-5':'-5';
  assert.throws(()=>x.h.submitBatch([{campaignCriterionOperation:{create:c}}]),/Google-assigned/);assert.equal(x.state.calls.length,0);
});
test('criterion rejection rolls back final stage, retains harmless paused shell, then resumes without duplicates',()=>{
  const store=pausedShell();assert.equal(store.campaigns.length,1);assert.equal(store.conversions.length,1);
  assert.equal(store.campaigns[0].status,'PAUSED');assert.equal(store.groups.length,0);assert.equal(store.assets.length,0);
  const before=clone(store.campaigns[0]);const x=run({},store);assert.equal(x.state.calls.length,1);
  assert.deepEqual(store.campaigns[0],before);assert.equal(store.campaigns.length,1);assert.equal(store.budgets.length,1);
  assert.equal(store.conversions.length,1);assert.equal(store.criteria.length,2);assert.equal(store.ads.length,1);
  const y=run({},store);assert.equal(y.state.calls.length,0);assert.match(log(y),/ALREADY CONFIGURED AND PAUSED/);
});
test('read-back discrepancy is never reported as completed even after successful mutations',()=>{
  const x=harness({hideLanguage:true});assert.throws(()=>x.h.main(),/verification is incomplete/);
  assert.match(log(x),/SETUP NOT VERIFIED/);assert.doesNotMatch(log(x),/SETUP COMPLETE/);
  assert.equal(x.state.store.campaigns[0].status,'PAUSED');
});
test('newly enabled parent is not given targeting or ads',()=>{
  const x=harness({beforeRead:(q,s)=>{if(q.includes('WHERE campaign.resource_name =')&&s.campaigns.length)s.campaigns[0].status='ENABLED';}});
  assert.throws(()=>x.h.main(),/Saved pilot is enabled/);assert.equal(x.state.calls.length,2);
  assert.equal(x.state.store.ads.length,0);
});
test('resume preserves original dates when creation happened yesterday',()=>{
  const store=pausedShell(),x=run({today:'2026-09-18'},store);
  assert.match(log(x),/"start": "2026-09-17"/);assert.equal(store.campaigns[0].endDateTime,'2026-09-30 23:59:59');
});
for(const [label,change] of [
  ['enabled',s=>s.campaigns[0].status='ENABLED'],['removed',s=>s.campaigns[0].status='REMOVED'],
  ['other campaign',s=>s.campaigns[0].name='User campaign'],
  ['wrong app',s=>s.campaigns[0].appCampaignSetting.appId='another.app'],
  ['higher budget',s=>s.budgets[0].amountMicros='30000000'],
  ['changed bidding',s=>s.campaigns[0].biddingStrategyType='TARGET_CPA'],
  ['extended dates',s=>s.campaigns[0].endDateTime='2027-09-30 23:59:59'],
  ['missing install selection',s=>s.campaigns[0].selectiveOptimization={conversionActions:[]}],
  ['wrong presence setting',s=>s.campaigns[0].geoTargetTypeSetting.positiveGeoTargetType='PRESENCE_OR_INTEREST']
])test('does not overwrite existing '+label,()=>{
  const store=pausedShell();change(store);const x=harness({},store);try{x.h.main();}catch(_){}
  assert.equal(x.state.calls.length,0);assert.doesNotMatch(log(x),/SETUP COMPLETE/);
});
test('expired paused pilot cannot be extended automatically',()=>{
  const x=harness({today:'2026-10-01'},pausedShell());assert.throws(()=>x.h.main(),/expired/);assert.equal(x.state.calls.length,0);
});
for(const defect of ['exclusion','wrong-country','disabled','duplicate'])test('conflicting '+defect+' targeting is not overwritten',()=>{
  const store=pausedShell();const c={campaign:store.campaigns[0].resourceName,type:'LOCATION',status:'ENABLED',negative:false,
    location:{geoTargetConstant:targets.country}};
  if(defect==='exclusion')c.negative=true;if(defect==='wrong-country')c.location.geoTargetConstant='geoTargetConstants/2840';
  if(defect==='disabled')c.status='PAUSED';store.criteria.push(c);if(defect==='duplicate')store.criteria.push(clone(c));
  const x=harness({},store);assert.throws(()=>x.h.main(),/Existing targeting differs/);assert.equal(x.state.calls.length,0);
});
test('only a missing language is added when known correct location already exists',()=>{
  const store=pausedShell();store.criteria.push({campaign:store.campaigns[0].resourceName,type:'LOCATION',status:'ENABLED',negative:false,
    location:{geoTargetConstant:targets.country}});
  const x=run({},store);assert.equal(creations(x,'campaignCriterionOperation').length,1);
  assert.equal(creations(x,'campaignCriterionOperation')[0].language.languageConstant,targets.language);
});
test('existing correct ad is reused while missing targeting is repaired',()=>{
  const first=run(),store=first.state.store;store.criteria=[];
  const x=run({},store);assert.equal(x.state.calls[0].length,2);assert.equal(store.ads.length,1);assert.equal(store.assets.length,3);
});
test('changed creative blocks repairs rather than replacing user copy',()=>{
  const store=run().state.store;store.criteria=[];store.ads[0].ad.appAd.headlines[0].text='Edited by owner';
  const x=harness({},store);assert.throws(()=>x.h.main(),/Existing ad differs/);assert.equal(x.state.calls.length,0);
});
test('conversion rejection prevents all parent writes',()=>{
  const x=harness({failKind:'conversionActionOperation'});assert.throws(()=>x.h.main());assert.equal(x.state.calls.length,1);
  assert.equal(x.state.store.campaigns.length,0);
});
test('parent rejection retains conversion only',()=>{
  const x=harness({failKind:'campaignOperation'});assert.throws(()=>x.h.main());assert.equal(x.state.calls.length,2);
  assert.equal(x.state.store.conversions.length,1);assert.equal(x.state.store.budgets.length,0);
});
for(const kind of ['conversionActionOperation','campaignOperation'])for(const bad of ['',OWNER+'/campaigns/-2','customers/9/campaigns/1'])
  test('unexpected returned '+kind+' ID stops dependent requests: '+bad,()=>{
    const x=harness({badResourceKind:kind,badResource:bad});assert.throws(()=>x.h.main(),/unexpected .* resource/);
    assert.equal(x.state.calls.length,kind==='conversionActionOperation'?1:2);assert.equal(x.state.store.ads.length,0);
  });
for(const defect of ['throw','short','null','missing-method','errors-throw'])test('ambiguous '+defect+' response never automatically retries',()=>{
  const x=harness({reply:ops=>{
    if(defect==='throw')throw new Error('Network timeout');if(defect==='short')return [];if(defect==='null')return null;
    return ops.map(()=>defect==='missing-method'?{}:{isSuccessful:()=>false,getErrorMessages:()=>{throw new Error('unreadable');}});
  }});assert.throws(()=>x.h.main(),/ambiguous/);assert.equal(x.state.calls.length,1);assert.doesNotMatch(log(x),/SETUP COMPLETE/);
});
for(const [currency,daily] of [['USD',3],['NGN',3000],['EUR',3],['GBP',2],['CAD',4],['AUD',4]])test(currency+' allowance unchanged',()=>{
  const x=run({currency});assert.equal(x.state.store.budgets[0].amountMicros,String(daily*1000000));
  assert.match(log(x),new RegExp('"conservativeWindowExposureBeforeTaxes": '+daily*28));
});
for(const [label,options] of [['wrong account',{customerId:'123-456-7890'}],['unknown currency',{currency:'JPY'}],
  ['prototype currency',{currency:'toString'}],['manager',{manager:true}],['missing owner',{owner:''}],
  ['manager-owned conversion missing',{owner:'customers/9'}],['missing country',{noCountry:true}],['missing language',{noLanguage:true}],
  ['impossible date',{today:'2026-02-30'}],['overflow date',{today:'9999-12-31'}],['missing images',{images:[]}],
  ['secondary conversion',{conversions:[conversion('77',{primaryForGoal:false})]}],
  ['hidden conversion',{conversions:[conversion('77',{status:'HIDDEN'})]}],
  ['wrong package',{conversions:[conversion('77',{appId:'other.app'})]}]])test(label+' fails before writes',()=>{
  const x=harness(options);assert.throws(()=>x.h.main());assert.equal(x.state.calls.length,0);
});
for(const defect of ['checksum','base64','name','bytes','dimensions','missing-ratio'])test('corrupt embedded '+defect+' stops all writes',()=>{
  const images=imageFixtures(),i=images[0];if(defect==='checksum')i.sha256='0'.repeat(64);if(defect==='base64')i.data='broken!';
  if(defect==='name')i.name='wrong';if(defect==='bytes')i.bytes++;if(defect==='dimensions')i.width=1;if(defect==='missing-ratio')i.height=1200;
  const x=harness({images});assert.throws(()=>x.h.main());assert.equal(x.state.calls.length,0);
});
test('real bundles contain the original three images and differ only in Preview flag',()=>{
  const main=fs.readFileSync(path.join(root,'ready','SoulBuddy-Ready-to-Run.js'),'utf8');
  const preview=fs.readFileSync(path.join(root,'ready','SoulBuddy-Preview-Check.js'),'utf8');
  assert.equal(main.replace('PREVIEW_CHECK_ONLY = false;','PREVIEW_CHECK_ONLY = true;'),preview);
  for(const code of [main,preview]){
    const x=run({code,preview:true});assert.equal(creations(x,'assetOperation').length,3);
    for(const image of x.h.EMBEDDED_IMAGES)assert.ok(image.bytes>10000);
    assert.ok(Buffer.byteLength(code)<1024*1024);assert.doesNotMatch(code,/UrlFetchApp|DriveApp|MailApp|eval\(/);
  }
});
test('unchanged goals, bids, dates and texts are present in saved campaign',()=>{
  const x=run(),c=x.state.store.campaigns[0],ad=x.state.store.ads[0].ad.appAd;
  assert.equal(c.appCampaignSetting.biddingStrategyGoalType,'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST');
  assert.deepEqual(c.maximizeConversions,{});assert.equal(c.targetCpa,undefined);
  assert.equal(c.startDateTime,'2026-09-17 00:00:00');assert.equal(c.endDateTime,'2026-09-30 23:59:59');
  assert.equal(c.geoTargetTypeSetting.positiveGeoTargetType,'PRESENCE');assert.equal(ad.headlines.length,5);
  assert.equal(ad.descriptions.length,5);assert.equal(ad.images.length,3);assert.equal(ad.youtubeVideos,undefined);
  x.h.validateText(x.h.HEADLINES,30);x.h.validateText(x.h.DESCRIPTIONS,90);
});
test('logs keep returned errors, redact long payloads and escape queries',()=>{
  const {h}=harness();assert.equal(h.diagnosticText('A'.repeat(400)),'[LONG_DATA_REDACTED]');
  assert.equal(h.quoted("a'b\\c"),"'a\\'b\\\\c'");assert.equal(h.addDays('2028-02-28',1),'2028-02-29');
  const x=harness({reply:ops=>ops.map(()=>({isSuccessful:()=>false,getErrorMessages:()=>['Google returned this error.']}))});
  assert.throws(()=>x.h.main());assert.match(log(x),/Google returned this error/);
});
