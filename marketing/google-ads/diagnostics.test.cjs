'use strict';
// Regression coverage for diagnostics. Mocks do NOT validate Google's live API.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const clone = value => JSON.parse(JSON.stringify(value));
const root = __dirname;

function harness(options = {}) {
  const filename = options.normal ? 'SoulBuddy-Ready-to-Run.js' : 'SoulBuddy-Preview-Check.js';
  const code = fs.readFileSync(path.join(root, 'ready', filename), 'utf8');
  const state = {logs: [], calls: [], reads: 0, preview: options.preview !== false};
  const box = {
    console: {log: text => state.logs.push(String(text))},
    Utilities: {
      DigestAlgorithm: {SHA_256: 'sha256'},
      base64Decode: value => Array.from(Buffer.from(value, 'base64')),
      computeDigest: (algorithm, bytes) => Array.from(crypto.createHash(algorithm).update(Buffer.from(bytes)).digest()),
      formatDate: () => '2026-09-17'
    },
    AdsApp: {
      getExecutionInfo: () => ({isPreview: () => state.preview}),
      currentAccount: () => ({getCustomerId: () => '790-445-9880', getCurrencyCode: () => 'USD',
        getTimeZone: () => 'Africa/Lagos'}),
      search: query => {
        state.reads++;
        let rows = [];
        if (query.includes('FROM customer')) rows = [{customer: {id: '7904459880', manager: false,
          conversionTrackingSetting: {googleAdsConversionCustomer: 'customers/7904459880'}}}];
        else if (query.includes('FROM geo_target_constant')) rows = [{geoTargetConstant: {
          resourceName: 'geoTargetConstants/2566', name: 'Nigeria'}}];
        else if (query.includes('FROM language_constant')) rows = [{languageConstant: {
          resourceName: 'languageConstants/1000'}}];
        else if (query.includes('FROM campaign') && options.existing) rows = [{campaign: {status: 'PAUSED', name: 'existing'}}];
        let i = 0;
        return {hasNext: () => i < rows.length, next: () => rows[i++]};
      },
      mutateAll: (operations, settings) => {
        const n = state.calls.length;
        state.calls.push({operations: clone(operations), settings: clone(settings)});
        if (options.reply) return options.reply(operations, n);
        return resultsFor(operations, options.failCampaign);
      }
    }
  };
  vm.createContext(box);
  vm.runInContext(code + '\nglobalThis.h = {main, submitBatch, previewCampaignProbes, diagnosticText, ' +
    'printOutcome, PREVIEW_CHECK_ONLY};', box);
  return {state, h: box.h, code};
}
function resultsFor(operations, failure = false, error = 'SIMULATED_CAMPAIGN_ERROR') {
  return operations.map(operation => ({
    isSuccessful: () => !(failure && operation.campaignOperation),
    getErrorMessages: () => [error],
    getResourceName: () => 'customers/7904459880/campaigns/9000'
  }));
}
function execute(x) {let error; try {x.h.main();} catch (e) {error = e;} return error;}

test('diagnostic Run is a no-op before reads or writes', () => {
    const x = harness({preview: false}); assert.equal(execute(x), undefined);
    assert.equal(x.state.calls.length, 0); assert.equal(x.state.reads, 0);
    assert.match(x.state.logs.join('\n'), /Click PREVIEW, not Run/);
});
test('diagnostic mutation helper independently refuses live invocation', () => {
  const x = harness({preview: false});
  assert.throws(() => x.h.submitBatch([]), /forbidden outside Google Preview/);
  assert.equal(x.state.calls.length, 0);
});
test('successful Preview does not suggest using diagnostic Run to install', () => {
  const x = harness(); assert.equal(execute(x), undefined);
  assert.equal(x.state.calls.length, 1);
  assert.match(x.state.logs.join('\n'), /unchanged full request passed this Preview/);
  assert.match(x.state.logs.join('\n'), /not proof/);
  assert.doesNotMatch(x.state.logs.join('\n'), /CREATED PAUSED|Click Run using/);
});
test('failed campaign is isolated without changing app, bidding, money or dates', () => {
  const x = harness({failCampaign: true}); assert.match(execute(x).message, /Atomic request rejected/);
  assert.equal(x.state.calls.length, 5);
  const original = x.state.calls[0].operations.find(op => op.campaignOperation).campaignOperation.create;
  for (const call of x.state.calls) {
    assert.deepEqual(call.settings, {apiVersion: 'v25', partialFailure: false});
    const campaign = call.operations.find(op => op.campaignOperation).campaignOperation.create;
    for (const field of ['status', 'appCampaignSetting', 'maximizeConversions', 'campaignBudget', 'startDateTime', 'endDateTime'])
      assert.deepEqual(campaign[field], original[field]);
    assert.equal(campaign.status, 'PAUSED');
  }
  assert.equal(x.state.calls[1].operations.length, 3); // conversion + budget + campaign
  assert.equal(x.state.calls[2].operations.at(-1).campaignOperation.create.selectiveOptimization, undefined);
  assert.deepEqual(x.state.calls[2].operations.at(-1).campaignOperation.create.geoTargetTypeSetting, original.geoTargetTypeSetting);
  assert.equal(x.state.calls[3].operations.at(-1).campaignOperation.create.geoTargetTypeSetting, undefined);
  assert.deepEqual(x.state.calls[3].operations.at(-1).campaignOperation.create.selectiveOptimization, original.selectiveOptimization);
  assert.equal(x.state.calls[4].operations.at(-1).campaignOperation.create.selectiveOptimization, undefined);
  assert.equal(x.state.calls[4].operations.at(-1).campaignOperation.create.geoTargetTypeSetting, undefined);
  assert.ok(original.selectiveOptimization && original.geoTargetTypeSetting); // original never modified
  assert.match(x.state.logs.join('\n'), /FULL_INSTALLER ERROR: SIMULATED_CAMPAIGN_ERROR/);
  assert.match(x.state.logs.join('\n'), /=== SOULBUDDY DIAGNOSTIC END ===/);
});
test('isolated campaign success stops optional-field probes', () => {
  const x = harness({reply: (ops, i) => resultsFor(ops, i === 0)});
  assert.ok(execute(x)); assert.equal(x.state.calls.length, 2);
});
test('normal installer never tries reduced campaigns in Preview or live mode', () => {
    for (const preview of [true, false]) {
      const x = harness({normal: true, preview, failCampaign: true}); assert.ok(execute(x));
      assert.equal(x.state.calls.length, 1);
      assert.match(x.state.logs.join('\n'), /FULL_INSTALLER ERROR/);
    }
});
test('non-campaign failure does not trigger campaign probes', () => {
  const x = harness({reply: ops => ops.map(op => ({isSuccessful: () => !op.assetOperation,
    getErrorMessages: () => ['SIMULATED_IMAGE_ERROR']}))});
  assert.ok(execute(x)); assert.equal(x.state.calls.length, 1);
});
for (const defect of ['throw', 'short', 'null', 'malformed-method', 'error-method-throws']) {
  test('ambiguous ' + defect + ' response does not trigger probes', () => {
    const x = harness({reply: ops => {
      if (defect === 'throw') throw new Error('simulated network timeout');
      if (defect === 'short') return [];
      if (defect === 'null') return null;
      return ops.map(() => defect === 'malformed-method' ? {} : ({isSuccessful: () => false,
        getErrorMessages: () => {throw new Error('unreadable');}}));
    }});
    assert.ok(execute(x)); assert.equal(x.state.calls.length, 1);
    assert.match(x.state.logs.join('\n'), /DIAGNOSTIC END/);
  });
}
test('transport failure inside a probe stops further probing', () => {
  const x = harness({reply: (ops, n) => {if (n === 1) throw new Error('timeout'); return resultsFor(ops, true);}});
  assert.ok(execute(x)); assert.equal(x.state.calls.length, 2);
});
test('direct probe call in normal installer is always forbidden', () => {
  const x = harness({normal: true}); assert.throws(() => x.h.previewCampaignProbes([]), /dedicated Preview Check/);
  assert.equal(x.state.calls.length, 0);
});
test('diagnostic log redacts long data and bounds individual messages', () => {
  const x = harness();
  assert.equal(x.h.diagnosticText('image=' + 'A'.repeat(400)), '[LONG_DATA_REDACTED]');
  assert.equal(x.h.diagnosticText({message: 'failure'}), 'failure');
  assert.ok(x.h.diagnosticText('long message '.repeat(1000)).length < 6100);
  assert.match(x.h.diagnosticText({errorCode: {campaignError: 'INVALID_FIELD'}, location: 'campaign.maximizeConversions'}), /INVALID_FIELD/);
});
test('unhelpful generic errors remain generic, never invented codes', () => {
  const generic = 'An error has occurred. Please try again later.';
  const x = harness({reply: ops => resultsFor(ops, true, generic)}); assert.ok(execute(x));
  assert.match(x.state.logs.join('\n'), /FULL_INSTALLER ERROR: An error has occurred/);
  assert.doesNotMatch(x.state.logs.join('\n'), /SIMULATED_CAMPAIGN_ERROR|INVALID_FIELD/);
});
test('empty error arrays and excessive messages are handled', () => {
  const operation = [{campaignOperation: {create: {}}}];
  const empty = harness({reply: () => [{isSuccessful: () => false, getErrorMessages: () => []}]}).h.submitBatch(operation);
  assert.match(empty.rows[0].errors[0], /no error details/);
  const many = harness({reply: () => [{isSuccessful: () => false, getErrorMessages: () => Array(99).fill('error')}]}).h.submitBatch(operation);
  assert.equal(many.rows[0].errors.length, 6);
  assert.match(many.rows[0].errors[5], /omitted/);
});
test('existing campaign prevents all diagnostic mutations', () => {
  const x = harness({existing: true}); assert.equal(execute(x), undefined); assert.equal(x.state.calls.length, 0);
});
test('distributed mode files differ only in their compiled safety flag', () => {
  const normal = harness({normal: true}), diagnostic = harness();
  assert.equal(normal.code.replace('PREVIEW_CHECK_ONLY = false;', 'PREVIEW_CHECK_ONLY = true;'), diagnostic.code);
  assert.equal(normal.h.PREVIEW_CHECK_ONLY, false); assert.equal(diagnostic.h.PREVIEW_CHECK_ONLY, true);
  for (const x of [normal, diagnostic]) assert.doesNotMatch(x.code, /UrlFetchApp|MailApp|DriveApp|eval\(|new Function\(/);
});
