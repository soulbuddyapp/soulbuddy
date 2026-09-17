/**
 * SoulBuddy account-ready install pilot. Reviewed 2026-09-17; Google Ads API v25.
 * This source is bundled with three EXISTING image ads by build-ready-script.py.
 * Paste the generated SoulBuddy-Ready-to-Run.js into Google Ads Scripts.
 * No configuration, video upload, media hosting, token, or app change is needed.
 * Run creates/reuses a REAL install conversion, then atomically creates PAUSED.
 * Preview saves nothing; a new conversion binding cannot be validated until Run.
 * No live campaign is submitted without an explicit positive conversion ID.
 * Do not schedule this installer. See README.md for budget and review details.
 * The generated Preview Check variant refuses to operate outside Google Preview.
 */
const SCRIPT_REVISION = '2026-09-17.criteria-names-1';
const PREVIEW_CHECK_ONLY = false; // @SOULBUDDY_PREVIEW_CHECK@
const PILOT = Object.freeze({
  customerId: '7904459880',
  appId: 'app.soulbuddy.soulbuddy',
  name: 'SoulBuddy | Android installs | NG | EN | Images v1',
  countryCode: 'NG', days: 14, apiVersion: 'v25'
});
// Fixed conservative planning allowances, NOT exchange rates or CPI forecasts.
const DAILY_ALLOWANCES = Object.freeze({USD: 3, NGN: 3000, GBP: 2, EUR: 3, CAD: 4, AUD: 4});
const HEADLINES = Object.freeze([
  'Let Christ Reshape Your Life',
  'Build Faithful Daily Habits',
  'Put Your Faith Into Practice',
  'Prayer, Scripture & Reflection',
  'Grow in Christ, Day by Day'
]);
const DESCRIPTIONS = Object.freeze([
  'Let Christ reshape everyday life through prayer, Scripture and small, faithful actions.',
  'Choose a personal goal. Build habits of prayer, reflection, forgiveness and love.',
  'Keep a prayer journal, set reminders and put your faith into practice each day.',
  'Begin with one faithful step. Pray, reflect and grow in the life you already have.',
  'Move beyond good intentions. Cultivate daily habits rooted in Christ.'
]);
// Build-time marker. An unbundled source fails before reading or changing Ads data.
const EMBEDDED_IMAGES = []; // @SOULBUDDY_IMAGES@

function main() {
  if (PREVIEW_CHECK_ONLY && AdsApp.getExecutionInfo().isPreview() !== true) {
    console.log('SOULBUDDY: Click PREVIEW, not Run. This diagnostic file never creates live resources.');
    return;
  }
  try {
    return setupPilot();
  } catch (error) {
    console.log('SOULBUDDY SCRIPT ERROR: ' + diagnosticText(error));
    throw error;
  }
}

function setupPilot() {
  console.log('SOULBUDDY BUILD ' + SCRIPT_REVISION +
    (AdsApp.getExecutionInfo().isPreview() ? ' | PREVIEW' : ' | LIVE EXECUTION (creates PAUSED)'));
  const account = AdsApp.currentAccount();
  const context = {
    customerId: account.getCustomerId().replace(/-/g, ''),
    currency: account.getCurrencyCode(),
    timezone: account.getTimeZone()
  };
  check(context.customerId === PILOT.customerId,
    'Wrong account. Open Google Ads account 790-445-9880 and run the same file there. No changes made.');
  context.today = Utilities.formatDate(new Date(), context.timezone, 'yyyy-MM-dd');
  const plan = makePlan(context);
  validateText(HEADLINES, 30);
  validateText(DESCRIPTIONS, 90);
  validateImages(EMBEDDED_IMAGES);

  // Do not create another copy, restart a removed pilot, or disturb another app campaign.
  const named = searchRows('SELECT campaign.resource_name, campaign.name, campaign.status FROM campaign ' +
    'WHERE campaign.name = ' + quoted(PILOT.name) +
    " AND campaign.status IN ('ENABLED', 'PAUSED', 'REMOVED')");
  if (named.length) return reportExisting(named);
  const active = searchRows('SELECT campaign.resource_name, campaign.name, campaign.status FROM campaign ' +
    'WHERE campaign.app_campaign_setting.app_id = ' + quoted(PILOT.appId) +
    " AND campaign.status IN ('ENABLED', 'PAUSED')");
  if (active.length) return reportExisting(active);

  const customer = one(searchRows('SELECT customer.id, customer.manager, ' +
    'customer.conversion_tracking_setting.google_ads_conversion_customer FROM customer'), 'customer').customer;
  check(String(customer.id) === context.customerId && customer.manager !== true,
    'Run this inside the paying customer account, not a manager account. No changes made.');
  const owner = customer.conversionTrackingSetting &&
    customer.conversionTrackingSetting.googleAdsConversionCustomer;
  check(typeof owner === 'string' && /^customers\/[1-9][0-9]*$/.test(owner),
    'Google did not return a conversion-owner account. No changes made; keep the execution log.');

  const country = one(searchRows(
    'SELECT geo_target_constant.resource_name, geo_target_constant.name FROM geo_target_constant ' +
    "WHERE geo_target_constant.country_code = 'NG' AND geo_target_constant.target_type = 'Country' " +
    "AND geo_target_constant.status = 'ENABLED'"), 'Nigeria country').geoTargetConstant;
  const language = one(searchRows(
    'SELECT language_constant.resource_name FROM language_constant ' +
    "WHERE language_constant.code = 'en' AND language_constant.targetable = TRUE"), 'English').languageConstant;

  const conversions = searchRows('SELECT conversion_action.resource_name, conversion_action.name, ' +
    'conversion_action.type, conversion_action.app_id, conversion_action.status, ' +
    'conversion_action.primary_for_goal FROM conversion_action ' +
    "WHERE conversion_action.type = 'GOOGLE_PLAY_DOWNLOAD' AND conversion_action.app_id = " + quoted(PILOT.appId) +
    " AND conversion_action.status IN ('ENABLED', 'HIDDEN', 'REMOVED')")
    .map(row => row.conversionAction);
  const conversion = planConversion(conversions, owner, context);
  const assets = searchRows('SELECT asset.resource_name, asset.name, asset.type, ' +
    'asset.image_asset.full_size.width_pixels, asset.image_asset.full_size.height_pixels FROM asset ' +
    'WHERE asset.name IN (' + EMBEDDED_IMAGES.map(image => quoted(image.name)).join(', ') + ')')
    .map(row => row.asset);
  const request = buildOperations(context, plan, country.resourceName, language.resourceName,
    conversion, EMBEDDED_IMAGES, assets);

  console.log(JSON.stringify({
    account: '790-445-9880', currency: context.currency, timezone: context.timezone,
    campaign: PILOT.name, country: country.name, language: 'English',
    averageDailyBudget: plan.daily, start: plan.start, end: plan.end,
    averageBudgetTimesDays: plan.planned, conservativeWindowExposureBeforeTaxes: plan.exposure,
    bidStrategy: 'Maximize installs; no target CPI', status: 'PAUSED',
    images: 3, videosUploaded: 0,
    installMeasurement: conversion.create ? 'Create SoulBuddy Google Play download action' : conversion.resourceName
  }, null, 2));
  console.log('Average budget x days is NOT a lifetime cap. A day may spend up to 2x the average. ' +
    'Taxes/fees and later budget/date changes are not included. Review before enabling.');
  console.log('No video upload or YouTube account is needed. Google may auto-generate video from image/store assets.');
  if (conversion.create) console.log('A new primary DOWNLOAD conversion is an account-level measurement resource. ' +
    'Review any other campaigns that use account-default DOWNLOAD goals before enabling this pilot.');

  const preview = AdsApp.getExecutionInfo().isPreview() === true;
  let createdConversion = '';
  if (conversion.create) {
    // A conversion created in Preview does not exist, even when reported SUCCESS.
    // In live mode create it separately and use Google's returned positive ID.
    // All local campaign/asset checks above have completed before this write.
    const outcome = submitBatch([buildConversionOperation(context)]);
    requireSuccess('INSTALL_CONVERSION', outcome, '');
    if (preview) {
      console.log('INSTALL_CONVERSION: Preview passed; no conversion was saved.');
      console.log('PREVIEW LIMITATION: campaign structure is tested without conversion selection. ' +
        'Run must create a real SoulBuddy conversion ID and bind it before campaign creation.');
    } else {
      createdConversion = persistedResource(outcome.results[0], owner, 'conversionActions');
      request.operations[request.campaignIndex].campaignOperation.create.selectiveOptimization = {
        conversionActions: [createdConversion]
      };
      console.log('INSTALL_CONVERSION CREATED: ' + createdConversion);
      console.log('This measurement action is retained if the separate campaign request fails. ' +
        'A later run looks it up instead of creating another one. Nothing has been enabled.');
    }
  }

  const stage = preview && conversion.create ? 'CAMPAIGN_STRUCTURE_PREVIEW' : 'CAMPAIGN_WITH_INSTALL_GOAL';
  const outcome = submitBatch(request.operations);
  requireSuccess(stage, outcome, createdConversion);
  if (preview) {
    if (PREVIEW_CHECK_ONLY) {
      console.log('=== SOULBUDDY DIAGNOSTIC BEGIN ===');
      printOutcome(stage, outcome);
      console.log('=== SOULBUDDY DIAGNOSTIC END ===');
    }
    console.log(conversion.create
      ? 'PREVIEW STRUCTURE PASSED. Nothing saved. Install-goal binding remains unvalidated until Run.'
      : 'PREVIEW PASSED WITH EXISTING INSTALL GOAL. Nothing saved.');
    console.log('A simulation is not proof that a later live request will succeed.');
    if (!PREVIEW_CHECK_ONLY) console.log('Use Run on this same unchanged script to create PAUSED.');
    return;
  }
  const resource = persistedResource(outcome.results[request.campaignIndex], 'customers/' + PILOT.customerId, 'campaigns');
  console.log('CREATED PAUSED: ' + resource);
  console.log('Images, text and the real install goal are attached. Confirm the Nigeria Play release, previews, ' +
    'install tracking, dates, spend and billing in Google Ads, then enable manually. No code editing is needed. ' +
    'The 14-day calendar window starts on creation, not when you later enable the campaign.');
}

function buildConversionOperation(context) {
  check(context.customerId === PILOT.customerId, 'Wrong conversion account.');
  return {conversionActionOperation: {create: {
    name: 'SoulBuddy | Google Play downloads | Install pilot',
    type: 'GOOGLE_PLAY_DOWNLOAD', category: 'DOWNLOAD', appId: PILOT.appId,
    status: 'ENABLED', primaryForGoal: true, countingType: 'ONE_PER_CLICK',
    clickThroughLookbackWindowDays: '30', viewThroughLookbackWindowDays: '1',
    valueSettings: {defaultValue: 0, defaultCurrencyCode: context.currency, alwaysUseDefaultValue: true}
  }}};
}

function persistedResource(result, owner, collection) {
  check(AdsApp.getExecutionInfo().isPreview() === false,
    'Preview results must never be treated as persisted resource IDs.');
  let resource;
  try {
    resource = result.getResourceName();
  } catch (error) {
    throw new Error('Google reported success but its ' + collection + ' resource could not be read. ' +
      'It may have been saved. Nothing was enabled; inspect before retrying. ' + diagnosticText(error));
  }
  check(typeof resource === 'string' &&
    new RegExp('^' + owner + '/' + collection + '/[1-9][0-9]*$').test(resource),
    'Google reported success but returned an unexpected ' + collection + ' resource. ' +
    'It may have been saved. Nothing was enabled; inspect before retrying.');
  return resource;
}

function requireSuccess(stage, outcome, retainedConversion) {
  if (outcome.ok) return;
  console.log('=== SOULBUDDY DIAGNOSTIC BEGIN ===');
  printOutcome(stage, outcome);
  if (retainedConversion) console.log('RETAINED INSTALL CONVERSION: ' + retainedConversion);
  console.log('Nothing was enabled. Stage results do not imply rollback of earlier successful requests.');
  console.log('=== SOULBUDDY DIAGNOSTIC END ===');
  if (outcome.exception || !outcome.complete || outcome.rows.some(row => row.status === 'UNKNOWN')) {
    throw new Error(stage + ': ambiguous Google Ads response. Inspect before retrying; a transport error can hide ' +
      'a committed result. No automatic retry was attempted. ' + (outcome.exception || ''));
  }
  throw new Error(stage + ': atomic request rejected. Earlier successful requests, if any, remain. ' +
    'Nothing was enabled. Read the SOULBUDDY DIAGNOSTIC block in Logs.');
}

// Only documented MutateResult methods are used. Do not dump raw image requests.
function submitBatch(operations) {
  check(!PREVIEW_CHECK_ONLY || AdsApp.getExecutionInfo().isPreview() === true,
    'Diagnostic writes are forbidden outside Google Preview.');
  operations.forEach(operation => {
    const campaign = operation.campaignOperation && operation.campaignOperation.create;
    if (!campaign) return;
    check(campaign.status === 'PAUSED', 'Installer must never enable a campaign.');
    const selection = campaign.selectiveOptimization;
    const bound = selection && Array.isArray(selection.conversionActions) && selection.conversionActions.length === 1 &&
      /^customers\/[1-9][0-9]*\/conversionActions\/[1-9][0-9]*$/.test(selection.conversionActions[0]);
    check(bound || (!selection && AdsApp.getExecutionInfo().isPreview() === true),
      'Campaign submission requires a real install-conversion ID. Temporary IDs and live unbound campaigns are forbidden.');
  });
  validateTargetingReferences(operations);
  let results;
  try {
    results = AdsApp.mutateAll(operations, {apiVersion: PILOT.apiVersion, partialFailure: false});
  } catch (error) {
    return {ok: false, complete: false, exception: diagnosticText(error), rows: []};
  }
  const complete = Array.isArray(results) && results.length === operations.length;
  const rows = operations.map((operation, index) => {
    const row = {index, operation: Object.keys(operation)[0], status: 'UNKNOWN', errors: []};
    const result = Array.isArray(results) ? results[index] : null;
    try {
      if (!result || typeof result.isSuccessful !== 'function') throw new Error('Missing MutateResult');
      row.status = result.isSuccessful() ? 'SUCCESS' : 'FAILED';
      if (row.status === 'FAILED') {
        const messages = result.getErrorMessages();
        row.errors = Array.isArray(messages) ? messages.slice(0, 5).map(diagnosticText) : [diagnosticText(messages)];
        if (Array.isArray(messages) && messages.length > 5) row.errors.push('[Additional error messages omitted]');
        if (!row.errors.length) row.errors.push('Google returned no error details.');
      }
    } catch (error) {
      row.status = 'UNKNOWN';
      row.errors.push('Cannot inspect result: ' + diagnosticText(error));
    }
    return row;
  });
  return {ok: complete && rows.every(row => row.status === 'SUCCESS'), complete, rows, results};
}

function diagnosticText(value) {
  let text;
  try {
    text = typeof value === 'string' ? value : value && typeof value.message === 'string'
      ? (value.name ? value.name + ': ' : '') + value.message : JSON.stringify(value);
  } catch (_) {
    text = String(value);
  }
  text = typeof text === 'string' ? text : String(value);
  // Preserve codes/field paths while preventing large binary/credential-like strings in logs.
  text = text.replace(/[A-Za-z0-9+/=_-]{160,}/g, '[LONG_DATA_REDACTED]');
  return text.length > 6000 ? text.slice(0, 6000) + ' [TRUNCATED]' : text;
}

function printOutcome(label, outcome) {
  console.log(label + ': ' + (outcome.ok ? 'PASS' : 'FAIL'));
  if (outcome.exception) console.log(label + ' EXCEPTION: ' + outcome.exception);
  if (!outcome.complete) console.log(label + ': incomplete/ambiguous response; persistence is not inferred.');
  outcome.rows.forEach(row => {
    console.log(label + ' op[' + row.index + '] ' + row.operation + ': ' + row.status);
    row.errors.forEach(message => console.log(label + ' ERROR: ' + message));
  });
}

function makePlan(context) {
  check(context.customerId === PILOT.customerId, 'Wrong account.');
  check(Object.prototype.hasOwnProperty.call(DAILY_ALLOWANCES, context.currency),
    'No reviewed allowance for account currency ' + context.currency + '. No changes made; keep this log.');
  check(typeof context.today === 'string' && validDate(context.today), 'Invalid account-local date.');
  const daily = DAILY_ALLOWANCES[context.currency];
  const end = addDays(context.today, PILOT.days - 1);
  check(validDate(end), 'End date is outside the supported calendar range.');
  return {daily, start: context.today, end, planned: daily * PILOT.days, exposure: daily * 2 * PILOT.days};
}

function planConversion(rows, owner, context) {
  const valid = rows.filter(row => row.type === 'GOOGLE_PLAY_DOWNLOAD' && row.appId === PILOT.appId);
  check(valid.length === rows.length, 'Unexpected conversion response. No changes made.');
  const eligible = valid.filter(row => row.status === 'ENABLED' && row.primaryForGoal === true &&
    typeof row.resourceName === 'string' &&
    new RegExp('^' + owner + '/conversionActions/[1-9][0-9]*$').test(row.resourceName))
    .sort((a, b) => compareResourceIds(a.resourceName, b.resourceName));
  if (eligible.length) {
    if (eligible.length > 1) console.log('Multiple primary Play-download actions exist for this exact app; ' +
      'selecting the lowest numeric ID only to avoid counting the same installation twice.');
    return {create: false, resourceName: eligible[0].resourceName};
  }
  check(valid.length === 0, 'SoulBuddy install measurement already exists but is disabled, secondary or owned elsewhere. ' +
    'Its settings were not overridden and no duplicate was created. Keep this log for review.');
  check(owner === 'customers/' + context.customerId,
    'Install conversions are managed by ' + owner + ', not this customer. No changes made; keep this log.');
  return {create: true, resourceName: null};
}

function buildOperations(context, plan, countryResource, languageResource, conversion, images, existingAssets) {
  check(context.customerId === PILOT.customerId, 'Wrong account.');
  check(/^geoTargetConstants\/[1-9][0-9]*$/.test(countryResource), 'Invalid country.');
  check(/^languageConstants\/[1-9][0-9]*$/.test(languageResource), 'Invalid language.');
  check(conversion.create === true ? conversion.resourceName === null :
    conversion.create === false && typeof conversion.resourceName === 'string' &&
    /^customers\/[1-9][0-9]*\/conversionActions\/[1-9][0-9]*$/.test(conversion.resourceName),
    'Expected a pending conversion or an existing positive conversion ID.');
  const prefix = 'customers/' + context.customerId;
  const budget = prefix + '/campaignBudgets/-1';
  const campaign = prefix + '/campaigns/-2';
  const adGroup = prefix + '/adGroups/-3';
  const operations = [];
  const imageResources = images.map((image, index) => {
    const matches = existingAssets.filter(asset => asset.name === image.name);
    matches.forEach(asset => {
      const full = asset.imageAsset && asset.imageAsset.fullSize;
      check(asset.type === 'IMAGE' && full && Number(full.widthPixels) === image.width &&
        Number(full.heightPixels) === image.height &&
        new RegExp('^' + prefix + '/assets/[1-9][0-9]*$').test(asset.resourceName),
        'An existing named image has an unexpected type, size or owner. No changes made.');
    });
    if (matches.length) return matches.sort((a, b) => compareResourceIds(a.resourceName, b.resourceName))[0].resourceName;
    const resourceName = prefix + '/assets/' + (-10 - index);
    operations.push({assetOperation: {create: {
      resourceName, name: image.name, type: 'IMAGE', imageAsset: {data: image.data}
    }}});
    return resourceName;
  });
  operations.push({campaignBudgetOperation: {create: {
    resourceName: budget, name: PILOT.name + ' | budget', amountMicros: String(toMicros(plan.daily)),
    explicitlyShared: false, deliveryMethod: 'STANDARD'
  }}});
  const campaignIndex = operations.length;
  operations.push({campaignOperation: {create: {
    resourceName: campaign, name: PILOT.name, status: 'PAUSED', campaignBudget: budget,
    advertisingChannelType: 'MULTI_CHANNEL', advertisingChannelSubType: 'APP_CAMPAIGN',
    appCampaignSetting: {appId: PILOT.appId, appStore: 'GOOGLE_APP_STORE',
      biddingStrategyGoalType: 'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST'},
    maximizeConversions: {},
    containsEuPoliticalAdvertising: 'DOES_NOT_CONTAIN_EU_POLITICAL_ADVERTISING',
    startDateTime: plan.start + ' 00:00:00', endDateTime: plan.end + ' 23:59:59',
    geoTargetTypeSetting: {positiveGeoTargetType: 'PRESENCE', negativeGeoTargetType: 'PRESENCE'}
  }}});
  // Pending conversion: retain an unbound LOCAL template only. submitBatch refuses
  // it in live mode until setupPilot injects a positive ID from a separate request.
  if (!conversion.create) {
    operations[campaignIndex].campaignOperation.create.selectiveOptimization = {
      conversionActions: [conversion.resourceName]
    };
  }
  // CampaignCriterion has a COMPOSITE resource name. Explicitly preserve the
  // parent campaign ID in both fields instead of leaving Preview to infer it.
  // The final negative IDs identify these new criteria, not the geo/language constants.
  const criteriaPrefix = campaign.replace('/campaigns/', '/campaignCriteria/') + '~';
  operations.push({campaignCriterionOperation: {create: {
    resourceName: criteriaPrefix + '-5', campaign, location: {geoTargetConstant: countryResource}
  }}});
  operations.push({campaignCriterionOperation: {create: {
    resourceName: criteriaPrefix + '-6', campaign, language: {languageConstant: languageResource}
  }}});
  operations.push({adGroupOperation: {create: {resourceName: adGroup, campaign,
    name: 'Christ-centered daily habits', status: 'ENABLED'}}});
  operations.push({adGroupAdOperation: {create: {adGroup, status: 'ENABLED', ad: {appAd: {
    headlines: HEADLINES.map(text => ({text})), descriptions: DESCRIPTIONS.map(text => ({text})),
    images: imageResources.map(asset => ({asset}))
  }}}}});
  validateTargetingReferences(operations);
  return {operations, campaignIndex};
}

// Project-specific preflight, not a reimplementation of Google's API validation.
// Refuse missing targeting, mismatched composite parents or duplicate temp IDs.
function validateTargetingReferences(operations) {
  const campaigns = operations.filter(op => op.campaignOperation).map(op => op.campaignOperation.create);
  const criteria = operations.filter(op => op.campaignCriterionOperation).map(op => op.campaignCriterionOperation.create);
  if (!campaigns.length && !criteria.length) return; // standalone conversion stage
  check(campaigns.length === 1 && criteria.length === 2,
    'Targeting preflight: the pilot requires one campaign and both location and language criteria.');
  const parent = campaigns[0] && campaigns[0].resourceName;
  check(typeof parent === 'string' &&
    new RegExp('^customers/' + PILOT.customerId + '/campaigns/-[1-9][0-9]*$').test(parent),
    'Targeting preflight: unexpected parent campaign resource.');
  const prefix = parent.replace('/campaigns/', '/campaignCriteria/') + '~';
  criteria.forEach(criterion => {
    check(criterion && criterion.campaign === parent && typeof criterion.resourceName === 'string' &&
      criterion.resourceName.startsWith(prefix) && /^-[1-9][0-9]*$/.test(criterion.resourceName.slice(prefix.length)),
      'Targeting preflight: criterion resourceName must contain the SAME campaign ID and a unique negative criterion ID.');
    check(criterion.negative === undefined || criterion.negative === false,
      'Targeting preflight: the pilot requires positive targets, not exclusions.');
  });
  const locations = criteria.filter(c => c.location && !c.language);
  const languages = criteria.filter(c => c.language && !c.location);
  check(locations.length === 1 && languages.length === 1 &&
    /^geoTargetConstants\/[1-9][0-9]*$/.test(locations[0].location.geoTargetConstant) &&
    /^languageConstants\/[1-9][0-9]*$/.test(languages[0].language.languageConstant),
    'Targeting preflight: one valid location and one valid language are required.');
  const ids = new Set();
  operations.forEach(operation => {
    const create = Object.values(operation)[0].create;
    if (!create || typeof create.resourceName !== 'string') return;
    const id = create.resourceName.split(/[\/~]/).pop();
    if (!/^-[1-9][0-9]*$/.test(id)) return;
    check(!ids.has(id), 'Targeting preflight: duplicate temporary resource ID ' + id + '.');
    ids.add(id);
  });
}

function validateImages(images) {
  check(Array.isArray(images) && images.length === 3,
    'Use the complete generated SoulBuddy-Ready-to-Run.js file, which contains three images. No changes made.');
  const expected = ['1200x628', '1200x1200', '1200x1500'];
  check(new Set(images.map(image => image.name)).size === 3, 'Duplicate embedded image names.');
  images.forEach(image => {
    check(expected.includes(image.width + 'x' + image.height), 'Unexpected embedded image dimensions.');
    check(typeof image.name === 'string' && /^SoulBuddy transformation [a-z]+ [a-f0-9]{16}$/.test(image.name),
      'Invalid embedded image name.');
    check(typeof image.data === 'string' && image.data.length < 7 * 1024 * 1024 &&
      image.data.length % 4 === 0 && /^[A-Za-z0-9+/]*={0,2}$/.test(image.data),
      'Embedded image data is incomplete. Copy the entire generated file.');
    const bytes = Utilities.base64Decode(image.data);
    check(bytes.length === image.bytes && bytes.length >= 4 && bytes.length <= 5 * 1024 * 1024 &&
      (bytes[0] & 255) === 255 && (bytes[1] & 255) === 216 &&
      (bytes[bytes.length - 2] & 255) === 255 && (bytes[bytes.length - 1] & 255) === 217,
      'Embedded JPEG failed integrity checks.');
    const digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, bytes)
      .map(byte => ('0' + (byte & 255).toString(16)).slice(-2)).join('');
    check(digest === image.sha256 && image.name.endsWith(digest.slice(0, 16)), 'Embedded image checksum mismatch.');
  });
  check(new Set(images.map(image => image.width + 'x' + image.height)).size === 3,
    'One of the three image aspect ratios is missing.');
}
function validateText(values, maximum) {
  check(Array.isArray(values) && values.length === 5 && new Set(values).size === 5, 'Invalid ad text count.');
  values.forEach(value => check(typeof value === 'string' && value.length > 0 && value.length <= maximum &&
    value.trim() === value && /^[\x20-\x7e]+$/.test(value), 'Invalid ad text.'));
}
function compareResourceIds(a, b) {
  const left = a.slice(a.lastIndexOf('/') + 1), right = b.slice(b.lastIndexOf('/') + 1);
  return left.length - right.length || (left < right ? -1 : left > right ? 1 : 0);
}
function reportExisting(rows) {
  console.log('STOP: a SoulBuddy campaign already exists. Nothing duplicated, changed or re-enabled.');
  rows.forEach(row => console.log(JSON.stringify(row.campaign)));
}
function searchRows(query) {
  const iterator = AdsApp.search(query, {apiVersion: PILOT.apiVersion});
  const rows = [];
  while (iterator.hasNext()) rows.push(iterator.next());
  return rows;
}
function one(rows, label) {
  check(rows.length === 1, 'Could not uniquely resolve ' + label + '. No changes made.');
  return rows[0];
}
function quoted(value) {
  return "'" + value.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'";
}
function toMicros(value) {
  const result = value * 1000000;
  check(Number.isSafeInteger(result) && result > 0, 'Invalid budget amount.');
  return result;
}
function validDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(value + 'T00:00:00Z');
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}
function addDays(value, days) {
  const date = new Date(value + 'T00:00:00Z');
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}
function check(condition, message) {
  if (!condition) throw new Error(message);
}
