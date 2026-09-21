/**
 * SoulBuddy account-ready install pilot. Reviewed 2026-09-17; Google Ads API v25.
 * This source is bundled with three EXISTING image ads by build-ready-script.py.
 * Paste the generated SoulBuddy-Ready-to-Run.js into Google Ads Scripts.
 * No configuration, video upload, media hosting, token, or app change is needed.
 * Run persists the install goal and PAUSED parent, then attaches targeting/ads.
 * Fresh Preview tests structure only; targeting needs a saved parent in Run.
 * No live campaign is submitted without an explicit positive conversion ID.
 * Do not schedule this installer. See README.md for budget and review details.
 * The generated Preview Check variant refuses to operate outside Google Preview.
 */
const SCRIPT_REVISION = '2026-09-17.persisted-targeting-1';
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
  const preview = AdsApp.getExecutionInfo().isPreview() === true;
  console.log('SOULBUDDY BUILD ' + SCRIPT_REVISION + (preview ? ' | PREVIEW' : ' | RUN (PAUSED ONLY)'));
  const account = AdsApp.currentAccount();
  const context = {customerId: account.getCustomerId().replace(/-/g, ''), currency: account.getCurrencyCode(),
    timezone: account.getTimeZone()};
  check(context.customerId === PILOT.customerId, 'Wrong account. Open 790-445-9880. No changes made.');
  context.today = Utilities.formatDate(new Date(), context.timezone, 'yyyy-MM-dd');
  let plan = makePlan(context);
  validateText(HEADLINES, 30);
  validateText(DESCRIPTIONS, 90);
  validateImages(EMBEDDED_IMAGES);

  const named = searchRows('SELECT campaign.resource_name, campaign.name, campaign.status FROM campaign ' +
    'WHERE campaign.name = ' + quoted(PILOT.name) + " AND campaign.status IN ('ENABLED', 'PAUSED', 'REMOVED')");
  check(named.length <= 1, 'Multiple same-named campaigns exist. No changes made; inspect the account.');
  if (named.length && named[0].campaign.status !== 'PAUSED') return reportExisting(named);
  const active = searchRows('SELECT campaign.resource_name, campaign.name, campaign.status FROM campaign ' +
    'WHERE campaign.app_campaign_setting.app_id = ' + quoted(PILOT.appId) +
    " AND campaign.status IN ('ENABLED', 'PAUSED')");
  const others = active.filter(row => !named.length || row.campaign.resourceName !== named[0].campaign.resourceName);
  if (others.length) return reportExisting(others);

  const customer = one(searchRows('SELECT customer.id, customer.manager, ' +
    'customer.conversion_tracking_setting.google_ads_conversion_customer FROM customer'), 'customer').customer;
  check(String(customer.id) === context.customerId && customer.manager !== true, 'Use the paying account, not a manager account.');
  const owner = customer.conversionTrackingSetting && customer.conversionTrackingSetting.googleAdsConversionCustomer;
  check(typeof owner === 'string' && /^customers\/[1-9][0-9]*$/.test(owner), 'Missing conversion owner. No changes made.');
  const country = one(searchRows('SELECT geo_target_constant.resource_name, geo_target_constant.name FROM geo_target_constant ' +
    "WHERE geo_target_constant.country_code = 'NG' AND geo_target_constant.target_type = 'Country' " +
    "AND geo_target_constant.status = 'ENABLED'"), 'Nigeria').geoTargetConstant;
  const language = one(searchRows('SELECT language_constant.resource_name FROM language_constant ' +
    "WHERE language_constant.code = 'en' AND language_constant.targetable = TRUE"), 'English').languageConstant;
  const targets = {country: country.resourceName, language: language.resourceName};
  validateConstants(targets);
  const conversions = searchRows('SELECT conversion_action.resource_name, conversion_action.name, conversion_action.type, ' +
    'conversion_action.app_id, conversion_action.status, conversion_action.primary_for_goal FROM conversion_action ' +
    "WHERE conversion_action.type = 'GOOGLE_PLAY_DOWNLOAD' AND conversion_action.app_id = " + quoted(PILOT.appId) +
    " AND conversion_action.status IN ('ENABLED', 'HIDDEN', 'REMOVED')").map(row => row.conversionAction);
  let conversion = planConversion(conversions, owner, context);
  const assets = searchRows('SELECT asset.resource_name, asset.name, asset.type, ' +
    'asset.image_asset.full_size.width_pixels, asset.image_asset.full_size.height_pixels FROM asset ' +
    'WHERE asset.name IN (' + EMBEDDED_IMAGES.map(image => quoted(image.name)).join(', ') + ')').map(row => row.asset);

  let campaign = named.length ? named[0].campaign.resourceName : '';
  let initialState;
  if (campaign) {
    initialState = inspectPilot(campaign, context, targets, conversions, assets);
    plan = initialState.plan; // Never reset or extend the dates of a saved pilot.
    conversion = {create: false, resourceName: initialState.conversion};
    if (initialState.complete) {
      console.log('ALREADY CONFIGURED AND PAUSED: ' + campaign + '. Nigeria, English, install goal and creative verified. No changes made.');
      return;
    }
    console.log('RESUMING MATCHING PAUSED PILOT: ' + campaign + '. Original budget and dates are retained.');
  }
  const parent = buildParentOperations(context, plan, conversion);
  // Complete local creative validation BEFORE any writes, including conversion creation.
  const creativeTemplate = buildCreativeOperations(context, campaign || parent.resourceName, EMBEDDED_IMAGES, assets,
    initialState && initialState.group, initialState && initialState.adComplete);
  console.log(JSON.stringify({account: '790-445-9880', currency: context.currency, timezone: context.timezone,
    campaign: PILOT.name, country: country.name, language: 'English', averageDailyBudget: plan.daily,
    start: plan.start, end: plan.end, averageBudgetTimesDays: plan.planned,
    conservativeWindowExposureBeforeTaxes: plan.exposure, status: 'PAUSED', images: 3, videosUploaded: 0,
    bidStrategy: 'Maximize installs; no target CPI', installMeasurement: conversion.create ? 'Create Google Play download action' : conversion.resourceName
  }, null, 2));
  console.log('Average budget x days is NOT a lifetime cap. A day may spend up to 2x average; taxes/fees are excluded.');
  console.log('No video upload is needed. Google may assemble video from image/store assets.');

  if (conversion.create) {
    console.log('A new primary DOWNLOAD action is account-level measurement. Review other account-default DOWNLOAD goals.');
    const outcome = submitBatch([buildConversionOperation(context)]);
    requireSuccess('INSTALL_CONVERSION', outcome, '');
    if (!preview) {
      conversion = {create: false, resourceName: persistedResource(outcome.results[0], owner, 'conversionActions')};
      // Add only the action that this successful request just persisted to our validated candidates.
      conversions.push(Object.assign({}, buildConversionOperation(context).conversionActionOperation.create,
        {resourceName: conversion.resourceName}));
      parent.operations[parent.campaignIndex].campaignOperation.create.selectiveOptimization = {conversionActions: [conversion.resourceName]};
      console.log('INSTALL_CONVERSION CREATED: ' + conversion.resourceName + '. Retained if a later stage fails.');
    }
  }
  if (!campaign && preview) {
    const outcome = submitBatch(parent.operations.concat(creativeTemplate));
    requireSuccess('STRUCTURE_PREVIEW', outcome, '');
    console.log('=== SOULBUDDY DIAGNOSTIC BEGIN ===');
    printOutcome('STRUCTURE_PREVIEW', outcome);
    console.log('TARGETING: DEFERRED, NOT VALIDATED BY GOOGLE. No saved campaign ID exists in Preview.');
    console.log(conversion.create ? 'INSTALL-GOAL BINDING: DEFERRED, NOT VALIDATED BY GOOGLE.' : 'INSTALL-GOAL BINDING: EXISTING ACTION USED.');
    console.log('=== SOULBUDDY DIAGNOSTIC END ===');
    console.log('PREVIEW PARTIAL CHECK PASSED. Nothing saved. This is NOT a complete targeting test.');
    if (!PREVIEW_CHECK_ONLY) console.log('Run this unchanged installer to create a PAUSED parent, attach targeting using its real ID, and read it back.');
    return;
  }
  if (!campaign) {
    const outcome = submitBatch(parent.operations);
    requireSuccess('PAUSED_PARENT', outcome, conversion.resourceName);
    campaign = persistedResource(outcome.results[parent.campaignIndex], 'customers/' + PILOT.customerId, 'campaigns');
    console.log('PAUSED PARENT CREATED (SETUP INCOMPLETE): ' + campaign + '. Do not enable yet.');
  }

  try {
    // Re-read just before finalization. Never attach ads to an enabled/altered campaign.
    const state = inspectPilot(campaign, context, targets, conversions, assets);
    const operations = buildTargetingOperations(campaign, targets, state.criteria).concat(
      buildCreativeOperations(context, campaign, EMBEDDED_IMAGES, assets, state.group, state.adComplete));
    if (operations.length) {
      const outcome = submitBatch(operations);
      requireSuccess('TARGETING_AND_CREATIVE', outcome, conversion.resourceName);
      if (preview) {
        console.log('=== SOULBUDDY DIAGNOSTIC BEGIN ===');
        printOutcome('TARGETING_AND_CREATIVE', outcome);
        console.log('=== SOULBUDDY DIAGNOSTIC END ===');
        console.log('PREVIEW PASSED AGAINST SAVED PAUSED PARENT. Nothing saved.');
        return;
      }
    }
    // Read back the actual targeting AND ad; a successful mutate alone is not readiness.
    const finalAssets = searchRows('SELECT asset.resource_name, asset.name, asset.type, ' +
      'asset.image_asset.full_size.width_pixels, asset.image_asset.full_size.height_pixels FROM asset ' +
      'WHERE asset.name IN (' + EMBEDDED_IMAGES.map(image => quoted(image.name)).join(', ') + ')').map(row => row.asset);
    const finalState = inspectPilot(campaign, context, targets, conversions, finalAssets);
    check(finalState.complete, 'Saved targeting/creative verification is incomplete. Keep the parent PAUSED; inspect before retrying.');
    console.log('SETUP COMPLETE - PAUSED: ' + campaign);
    console.log('VERIFIED: Nigeria, English, real install goal, three images, five headlines and five descriptions.');
    console.log('Review dates, previews, policy status and billing; only then enable manually. This installer never enables ads.');
  } catch (error) {
    console.log('SETUP NOT VERIFIED: retain PAUSED parent ' + campaign + '. No automatic enable, delete or retry.');
    console.log('Earlier successful requests remain saved. A later run can resume a matching paused pilot without changing budget/dates.');
    throw error;
  }
}

function validateConstants(targets) {
  check(/^geoTargetConstants\/[1-9][0-9]*$/.test(targets.country) &&
    /^languageConstants\/[1-9][0-9]*$/.test(targets.language), 'Invalid resolved country or language.');
}
function isSavedCampaign(resource) {
  return typeof resource === 'string' && new RegExp('^customers/' + PILOT.customerId + '/campaigns/[1-9][0-9]*$').test(resource);
}
function buildParentOperations(context, plan, conversion) {
  check(context.customerId === PILOT.customerId, 'Wrong parent account.');
  check(conversion.create === true ? conversion.resourceName === null : conversion.create === false &&
    /^customers\/[1-9][0-9]*\/conversionActions\/[1-9][0-9]*$/.test(conversion.resourceName), 'Invalid conversion plan.');
  const prefix = 'customers/' + context.customerId;
  const budget = prefix + '/campaignBudgets/-1', campaign = prefix + '/campaigns/-2';
  const create = {resourceName: campaign, name: PILOT.name, status: 'PAUSED', campaignBudget: budget,
    advertisingChannelType: 'MULTI_CHANNEL', advertisingChannelSubType: 'APP_CAMPAIGN',
    appCampaignSetting: {appId: PILOT.appId, appStore: 'GOOGLE_APP_STORE',
      biddingStrategyGoalType: 'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST'}, maximizeConversions: {},
    containsEuPoliticalAdvertising: 'DOES_NOT_CONTAIN_EU_POLITICAL_ADVERTISING',
    startDateTime: plan.start + ' 00:00:00', endDateTime: plan.end + ' 23:59:59',
    geoTargetTypeSetting: {positiveGeoTargetType: 'PRESENCE', negativeGeoTargetType: 'PRESENCE'}};
  if (!conversion.create) create.selectiveOptimization = {conversionActions: [conversion.resourceName]};
  return {resourceName: campaign, campaignIndex: 1, operations: [
    {campaignBudgetOperation: {create: {resourceName: budget, name: PILOT.name + ' | budget',
      amountMicros: String(toMicros(plan.daily)), explicitlyShared: false, deliveryMethod: 'STANDARD'}}},
    {campaignOperation: {create}}
  ]};
}

// Follows Google's Add App Campaign example: create the parent, use the returned
// campaign resource, then let Google assign criterion resource names. No guessed
// composite IDs and no campaignCriterion mutation against a temporary parent.
function buildTargetingOperations(campaign, targets, existing) {
  check(isSavedCampaign(campaign), 'Targeting requires a saved positive campaign ID, even in Preview.');
  validateConstants(targets);
  const present = inspectTargeting(campaign, targets, existing);
  const operations = [];
  if (!present.location) operations.push({campaignCriterionOperation: {create: {
    campaign, negative: false, location: {geoTargetConstant: targets.country}
  }}});
  if (!present.language) operations.push({campaignCriterionOperation: {create: {
    campaign, negative: false, language: {languageConstant: targets.language}
  }}});
  return operations;
}
function inspectTargeting(campaign, targets, criteria) {
  const present = {location: false, language: false};
  criteria.forEach(c => {
    const type = c.type === 'LOCATION' ? 'location' : c.type === 'LANGUAGE' ? 'language' : '';
    const matches = type === 'location' ? c.location && c.location.geoTargetConstant === targets.country
      : type === 'language' && c.language && c.language.languageConstant === targets.language;
    check(type && matches && c.campaign === campaign && c.status === 'ENABLED' &&
      (c.negative === false || c.negative === undefined) && !present[type],
      'Existing targeting differs, is disabled/excluded or duplicated. Nothing will be overwritten.');
    present[type] = true;
  });
  return present;
}
function buildCreativeOperations(context, campaign, images, existingAssets, savedGroup, complete) {
  check(context.customerId === PILOT.customerId && (isSavedCampaign(campaign) ||
    campaign === 'customers/' + PILOT.customerId + '/campaigns/-2'), 'Invalid creative parent.');
  const prefix = 'customers/' + context.customerId;
  check(!savedGroup || new RegExp('^' + prefix + '/adGroups/[1-9][0-9]*$').test(savedGroup), 'Invalid existing ad group.');
  if (complete) return [];
  const operations = [];
  const imageResources = images.map((image, index) => {
    const resource = existingImage(image, existingAssets, context.customerId);
    if (resource) return resource;
    const resourceName = prefix + '/assets/' + (-10 - index);
    operations.push({assetOperation: {create: {resourceName, name: image.name, type: 'IMAGE', imageAsset: {data: image.data}}}});
    return resourceName;
  });
  const adGroup = savedGroup || prefix + '/adGroups/-3';
  if (!savedGroup) operations.push({adGroupOperation: {create: {
    resourceName: adGroup, campaign, name: 'Christ-centered daily habits', status: 'ENABLED'
  }}});
  operations.push({adGroupAdOperation: {create: {adGroup, status: 'ENABLED', ad: {appAd: {
    headlines: HEADLINES.map(text => ({text})), descriptions: DESCRIPTIONS.map(text => ({text})),
    images: imageResources.map(asset => ({asset}))
  }}}}});
  return operations;
}
function existingImage(image, assets, customerId) {
  const matches = assets.filter(asset => asset.name === image.name);
  matches.forEach(asset => {
    const full = asset.imageAsset && asset.imageAsset.fullSize;
    check(asset.type === 'IMAGE' && full && Number(full.widthPixels) === image.width && Number(full.heightPixels) === image.height &&
      new RegExp('^customers/' + customerId + '/assets/[1-9][0-9]*$').test(asset.resourceName),
      'Existing named image has an unexpected type, size or owner. No replacement will be made.');
  });
  return matches.length ? matches.sort((a, b) => compareResourceIds(a.resourceName, b.resourceName))[0].resourceName : null;
}

function inspectPilot(resource, context, targets, conversions, assets) {
  check(isSavedCampaign(resource), 'Cannot inspect a temporary or foreign campaign.');
  const row = one(searchRows('SELECT campaign.resource_name, campaign.name, campaign.status, ' +
    'campaign.advertising_channel_type, campaign.advertising_channel_sub_type, campaign.bidding_strategy_type, ' +
    'campaign.app_campaign_setting.app_id, campaign.app_campaign_setting.app_store, ' +
    'campaign.app_campaign_setting.bidding_strategy_goal_type, campaign.selective_optimization.conversion_actions, ' +
    'campaign.start_date_time, campaign.end_date_time, campaign.geo_target_type_setting.positive_geo_target_type, ' +
    'campaign.geo_target_type_setting.negative_geo_target_type, campaign_budget.amount_micros, campaign_budget.explicitly_shared ' +
    'FROM campaign WHERE campaign.resource_name = ' + quoted(resource)), 'saved campaign');
  const c = row.campaign, b = row.campaignBudget, app = c.appCampaignSetting || {}, geo = c.geoTargetTypeSetting || {};
  const selection = c.selectiveOptimization && c.selectiveOptimization.conversionActions;
  const start = String(c.startDateTime || '').slice(0, 10), end = String(c.endDateTime || '').slice(0, 10);
  check(c.resourceName === resource && c.name === PILOT.name && c.status === 'PAUSED' &&
    c.advertisingChannelType === 'MULTI_CHANNEL' && c.advertisingChannelSubType === 'APP_CAMPAIGN' &&
    c.biddingStrategyType === 'MAXIMIZE_CONVERSIONS' && app.appId === PILOT.appId && app.appStore === 'GOOGLE_APP_STORE' &&
    app.biddingStrategyGoalType === 'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST' &&
    geo.positiveGeoTargetType === 'PRESENCE' && geo.negativeGeoTargetType === 'PRESENCE' && b && b.explicitlyShared === false &&
    String(b.amountMicros) === String(toMicros(DAILY_ALLOWANCES[context.currency])) &&
    validDate(start) && validDate(end) && addDays(start, PILOT.days - 1) === end && end >= context.today,
    'Saved pilot is enabled, expired or differs from the expected app/budget/bidding/dates. No changes made to it.');
  check(Array.isArray(selection) && selection.length === 1 && conversions.some(action =>
    action.resourceName === selection[0] && action.type === 'GOOGLE_PLAY_DOWNLOAD' && action.appId === PILOT.appId &&
    action.status === 'ENABLED' && action.primaryForGoal === true), 'Saved pilot lacks the intended active install goal. No override made.');
  const criteria = searchRows('SELECT campaign_criterion.resource_name, campaign_criterion.campaign, campaign_criterion.status, ' +
    'campaign_criterion.type, campaign_criterion.negative, campaign_criterion.location.geo_target_constant, ' +
    'campaign_criterion.language.language_constant FROM campaign_criterion WHERE campaign_criterion.campaign = ' + quoted(resource) +
    " AND campaign_criterion.type IN ('LOCATION', 'LANGUAGE') AND campaign_criterion.status != 'REMOVED'")
    .map(r => r.campaignCriterion);
  const present = inspectTargeting(resource, targets, criteria);
  const groups = searchRows('SELECT ad_group.resource_name, ad_group.campaign, ad_group.name, ad_group.status FROM ad_group ' +
    'WHERE ad_group.campaign = ' + quoted(resource) + " AND ad_group.status != 'REMOVED'").map(r => r.adGroup);
  check(groups.length <= 1 && groups.every(g => g.campaign === resource && g.status === 'ENABLED' &&
    g.name === 'Christ-centered daily habits' && new RegExp('^customers/' + PILOT.customerId + '/adGroups/[1-9][0-9]*$').test(g.resourceName)),
    'Existing ad groups differ from this pilot. Nothing will be overwritten.');
  const group = groups.length ? groups[0].resourceName : null;
  let adComplete = false;
  if (group) {
    const ads = searchRows('SELECT ad_group_ad.status, ad_group_ad.ad.type, ad_group_ad.ad.app_ad.headlines, ' +
      'ad_group_ad.ad.app_ad.descriptions, ad_group_ad.ad.app_ad.images FROM ad_group_ad WHERE ad_group_ad.ad_group = ' + quoted(group) +
      " AND ad_group_ad.status != 'REMOVED'").map(r => r.adGroupAd);
    check(ads.length <= 1, 'Multiple ads exist; no duplicate or replacement will be created.');
    if (ads.length) {
      const ad = ads[0], appAd = ad.ad && ad.ad.appAd;
      const imageResources = EMBEDDED_IMAGES.map(image => existingImage(image, assets, context.customerId));
      check(ad.status === 'ENABLED' && ad.ad.type === 'APP_AD' && appAd &&
        sameMembers((appAd.headlines || []).map(x => x.text), HEADLINES) &&
        sameMembers((appAd.descriptions || []).map(x => x.text), DESCRIPTIONS) && imageResources.every(Boolean) &&
        sameMembers((appAd.images || []).map(x => x.asset), imageResources), 'Existing ad differs from the pilot. No overwrite made.');
      adComplete = true;
    }
  }
  const daily = DAILY_ALLOWANCES[context.currency];
  return {criteria, group, adComplete, complete: present.location && present.language && adComplete,
    conversion: selection[0], plan: {daily, start, end, planned: daily * PILOT.days, exposure: daily * PILOT.days * 2}};
}
function sameMembers(left, right) {
  return left.length === right.length && JSON.stringify(left.slice().sort()) === JSON.stringify(right.slice().sort());
}

// Local shape guard only. Google's service validates resource semantics.
function validateTargetingReferences(operations) {
  const parentCreates = operations.filter(op => op.campaignOperation).map(op => op.campaignOperation.create);
  const criteria = operations.filter(op => op.campaignCriterionOperation).map(op => op.campaignCriterionOperation.create);
  check(!criteria.length || !parentCreates.length, 'Never create criteria in the parent-creation request.');
  const keys = new Set();
  criteria.forEach(c => {
    check(c && isSavedCampaign(c.campaign) && c.resourceName === undefined && c.criterionId === undefined,
      'Targeting requires a persisted campaign and Google-assigned criterion IDs.');
    check(c.negative === false, 'Targeting must be positive, not excluded.');
    const location = c.location && !c.language && /^geoTargetConstants\/[1-9][0-9]*$/.test(c.location.geoTargetConstant);
    const language = c.language && !c.location && /^languageConstants\/[1-9][0-9]*$/.test(c.language.languageConstant);
    check(Boolean(location) !== Boolean(language), 'One location or one language per criterion.');
    const key = c.campaign + (location ? ':location' : ':language');
    check(!keys.has(key), 'Duplicate targeting type in one request.');
    keys.add(key);
  });
  const ids = new Set();
  operations.forEach(op => {
    check(Object.keys(op).length === 1, 'Invalid mutation operation.');
    const value = Object.values(op)[0];
    check(value && Object.keys(value).length === 1 && value.create, 'Installer only creates; updates/removals are forbidden.');
    const c = value.create;
    if (typeof c.resourceName !== 'string') return;
    const id = c.resourceName.split('/').pop();
    if (!/^-[1-9][0-9]*$/.test(id)) return;
    check(!ids.has(id), 'Duplicate temporary resource ID.'); ids.add(id);
  });
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
