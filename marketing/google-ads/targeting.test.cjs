'use strict';
// Offline reference-contract regression tests. These do NOT emulate or certify
// Google's Preview/API implementation; the observed error is preserved as evidence.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ROOT = __dirname;
const source = fs.readFileSync(path.join(ROOT, 'setup-google-ads.js'), 'utf8');
const fixture = JSON.parse(fs.readFileSync(path.join(ROOT, 'fixtures', 'criteria-resource-name-error.json'), 'utf8'));
const clone = value => JSON.parse(JSON.stringify(value));
const context = {customerId: '7904459880', currency: 'USD', today: '2026-09-17'};
const goal = {create: false, resourceName: 'customers/7904459880/conversionActions/77'};
function load(code = source) {
  const state = {calls: []};
  const box = {console: {log: () => {}}, AdsApp: {
    getExecutionInfo: () => ({isPreview: () => true}),
    mutateAll: (ops, settings) => {
      state.calls.push({operations: clone(ops), settings: clone(settings)});
      return ops.map(() => ({isSuccessful: () => true, getErrorMessages: () => []}));
    }
  }};
  vm.createContext(box);
  vm.runInContext(code + '\nglobalThis.api = {makePlan, buildOperations, submitBatch, validateTargetingReferences, EMBEDDED_IMAGES};', box);
  return {h: box.api, state};
}
function request(h, images = []) {
  return h.buildOperations(context, h.makePlan(context), 'geoTargetConstants/2566', 'languageConstants/1000', goal, images, []);
}
function criteria(ops) { return ops.filter(op => op.campaignCriterionOperation).map(op => op.campaignCriterionOperation.create); }

test('the supplied failure is a criterion resource-name conflict, not a geo/language lookup error', () => {
  assert.equal(fixture.location, 'campaignCriterionOperation.create.resourceName');
  assert.equal(fixture.message, "The field's contents don't match another field that represents the same data.");
  assert.equal(fixture.criteria[0].location.geoTargetConstant, 'geoTargetConstants/2566');
  assert.equal(fixture.criteria[1].language.languageConstant, 'languageConstants/1000');
  assert.ok(fixture.criteria.every(c => c.resourceName === undefined));
});
test('both targeting entries have explicit composite names referencing the same parent', () => {
  const {h} = load(); const r = request(h); const c = r.operations[r.campaignIndex].campaignOperation.create;
  const targets = criteria(r.operations);
  assert.deepEqual(clone(targets).map(t => t.resourceName), [
    'customers/7904459880/campaignCriteria/-2~-5', 'customers/7904459880/campaignCriteria/-2~-6']);
  assert.ok(targets.every(t => t.campaign === c.resourceName));
  assert.deepEqual(clone(targets).map(({resourceName, ...rest}) => rest), fixture.criteria);
});
test('no temporary ID is reused, including across composite resource types', () => {
  const {h} = load();
  const images = [0,1,2].map(i => ({name:'image'+i, data:'test'}));
  const ops = request(h, images).operations;
  const ids = ops.map(op => Object.values(op)[0].create.resourceName).filter(Boolean).map(ref => ref.split(/[\/~]/).pop());
  assert.deepEqual(clone(ids).sort(), ['-1','-2','-3','-5','-6','-10','-11','-12'].sort());
  assert.equal(new Set(ids).size, ids.length);
});
test('missing implicit names from the original request now fail locally before mutation', () => {
  const {h, state} = load(); const r = request(h);
  for (const target of criteria(r.operations)) delete target.resourceName;
  assert.throws(() => h.submitBatch(r.operations), /criterion resourceName must contain the SAME campaign ID/);
  assert.equal(state.calls.length, 0);
});
for (const [label, change] of [
  ['wrong parent', (targets) => {targets[0].resourceName = targets[0].resourceName.replace('/-2~', '/-99~');}],
  ['wrong account', (targets) => {targets[0].resourceName = targets[0].resourceName.replace('7904459880','1234567890');}],
  ['wrong campaign field', (targets) => {targets[1].campaign = 'customers/7904459880/campaigns/-99';}],
  ['duplicate criterion ID', (targets) => {targets[1].resourceName = targets[0].resourceName;}],
  ['collision with budget ID', (targets) => {targets[0].resourceName = targets[0].resourceName.replace('~-5','~-1');}],
  ['positive newly assigned ID', (targets) => {targets[0].resourceName = targets[0].resourceName.replace('~-5','~2566');}],
  ['missing composite delimiter', (targets) => {targets[0].resourceName = targets[0].resourceName.replace('~','/');}],
  ['extra suffix', (targets) => {targets[0].resourceName += '~1';}],
  ['excluded instead of targeted', (targets) => {targets[0].negative = true;}],
  ['same type twice', (targets) => {targets[1].location = targets[0].location; delete targets[1].language;}],
  ['invalid constant', (targets) => {targets[0].location.geoTargetConstant = 'geoTargetConstants/NG';}],
  ['mixed criterion types', (targets) => {targets[0].language = targets[1].language;}]
]) {
  test(label + ' is blocked before the Google mutation call', () => {
    const {h, state} = load(); const r = request(h); change(criteria(r.operations));
    assert.throws(() => h.submitBatch(r.operations), /Targeting preflight/);
    assert.equal(state.calls.length, 0);
  });
}
test('removing either target cannot silently widen targeting', () => {
  for (const type of ['location','language']) {
    const {h, state} = load(); const r = request(h);
    r.operations = r.operations.filter(op => !op.campaignCriterionOperation?.create[type]);
    assert.throws(() => h.submitBatch(r.operations), /both location and language criteria/);
    assert.equal(state.calls.length, 0);
  }
});
test('standalone conversion request does not require unrelated targeting objects', () => {
  const {h, state} = load();
  const result = h.submitBatch([{conversionActionOperation: {create: {name:'example'}}}]);
  assert.equal(result.ok, true); assert.equal(state.calls.length, 1);
});
test('all nine operations remain atomic in the full generated distribution', () => {
  const code = fs.readFileSync(path.join(ROOT,'ready','SoulBuddy-Ready-to-Run.js'), 'utf8');
  const {h, state} = load(code); const r = request(h, h.EMBEDDED_IMAGES);
  assert.equal(r.operations.length, 9); assert.equal(h.submitBatch(r.operations).ok, true);
  assert.deepEqual(state.calls[0].settings, {apiVersion:'v25', partialFailure:false});
  const c = r.operations[r.campaignIndex].campaignOperation.create;
  assert.equal(c.status, 'PAUSED'); assert.deepEqual(clone(c.selectiveOptimization.conversionActions), [goal.resourceName]);
  assert.equal(c.geoTargetTypeSetting.positiveGeoTargetType, 'PRESENCE');
  assert.equal(r.operations.find(op => op.campaignBudgetOperation).campaignBudgetOperation.create.amountMicros, '3000000');
  const ad = r.operations.find(op => op.adGroupAdOperation).adGroupAdOperation.create.ad.appAd;
  assert.equal(ad.images.length,3); assert.equal(ad.headlines.length,5); assert.equal(ad.descriptions.length,5);
  assert.equal(ad.youtubeVideos,undefined);
});
