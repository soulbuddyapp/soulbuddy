/**
 * SoulBuddy Android install pilot | Google Ads Scripts | reviewed 2026-09-17.
 * Paste this entire file into Tools > Bulk actions > Scripts in the AD account.
 * No developer token, external service, package, secret, or app change is needed.
 * PLAN is read-only. CREATE_PAUSED creates a PAUSED campaign, never enables it.
 * Read README.md before changing configuration. Run only one copy at a time.
 */
const CONFIG = {
  mode: 'PLAN', // PLAN | CREATE_PAUSED
  expectedCustomerId: '', // Your 10-digit Google Ads customer ID, with or without hyphens.
  expectedCurrency: '', // Exact account currency, e.g. USD or NGN; no currency conversion.
  countryCode: '', // ONE chosen ISO country code, e.g. NG. No location is assumed.
  dailyBudget: null, // Positive amount in ACCOUNT currency; an AVERAGE, not a hard daily cap.
  testDays: 14, // Finite 1-30 day window, including startDate.
  startDate: '', // YYYY-MM-DD in account timezone. Empty = day of creation.
  targetCpi: null, // null = Maximize installs. Set a positive amount ONLY with evidence.
  acknowledgeSpendLimits: false, // Read the logged exposure before setting true for creation.
  installConversionResource: '', // Optional exact resource from PLAN when multiple installs exist.
  campaignKey: 'SoulBuddy | Android | Faithful habits | Pilot v1',
  // Optional assets ALREADY uploaded to THIS Ads account, not URLs or file paths.
  imageAssetResources: [], // e.g. customers/1234567890/assets/123
  videoAssetResources: [], // YouTube video asset resources, not raw YouTube IDs.
  headlines: [
    'Let Christ Reshape Your Life',
    'Build Faithful Daily Habits',
    'Put Your Faith Into Practice',
    'Prayer, Scripture & Reflection',
    'Grow in Christ, Day by Day'
  ],
  descriptions: [
    'Let Christ reshape everyday life through prayer, Scripture and small, faithful actions.',
    'Choose a personal goal. Build habits of prayer, reflection, forgiveness and love.',
    'Keep a prayer journal, set reminders and put your faith into practice each day.',
    'Begin with one faithful step. Pray, reflect and grow in the life you already have.',
    'Move beyond good intentions. Cultivate daily habits rooted in Christ.'
  ]
};
const APP_ID = 'app.soulbuddy.soulbuddy';
const API_VERSION = 'v25';

function main() {
  const account = AdsApp.currentAccount();
  const context = {
    customerId: account.getCustomerId().replace(/-/g, ''),
    currency: account.getCurrencyCode(),
    today: Utilities.formatDate(new Date(), account.getTimeZone(), 'yyyy-MM-dd')
  };
  console.log('Account: ' + context.customerId + ' | ' + context.currency + ' | ' + account.getTimeZone());
  const plan = validateConfig(CONFIG, context);
  const existing = searchRows(
    'SELECT campaign.resource_name, campaign.name, campaign.status FROM campaign ' +
    'WHERE campaign.name = ' + gaqlString(plan.name) +
    " AND campaign.status IN ('ENABLED', 'PAUSED', 'REMOVED')"
  );
  if (existing.length) {
    console.log('STOP: this campaign name already exists. Nothing was changed or re-enabled.');
    existing.forEach(row => console.log(JSON.stringify(row.campaign)));
    return;
  }
  const country = exactlyOne(searchRows(
    'SELECT geo_target_constant.resource_name, geo_target_constant.name FROM geo_target_constant ' +
    'WHERE geo_target_constant.country_code = ' + gaqlString(CONFIG.countryCode) +
    " AND geo_target_constant.target_type = 'Country' AND geo_target_constant.status = 'ENABLED'"
  ), 'enabled country').geoTargetConstant;
  const language = exactlyOne(searchRows(
    'SELECT language_constant.resource_name FROM language_constant ' +
    "WHERE language_constant.code = 'en' AND language_constant.targetable = TRUE"
  ), 'targetable English language').languageConstant;
  const conversions = searchRows(
    'SELECT conversion_action.resource_name, conversion_action.name, conversion_action.app_id, ' +
    'conversion_action.type, conversion_action.status, conversion_action.primary_for_goal FROM conversion_action ' +
    "WHERE conversion_action.type = 'GOOGLE_PLAY_DOWNLOAD' AND conversion_action.status = 'ENABLED' " +
    "AND conversion_action.primary_for_goal = TRUE " +
    'AND conversion_action.app_id = ' + gaqlString(APP_ID)
  ).map(row => row.conversionAction);
  console.log('Matching enabled primary Google Play download conversions: ' + JSON.stringify(conversions));
  const conversion = chooseConversion(conversions, CONFIG.installConversionResource);
  verifyAssets(CONFIG.imageAssetResources, 'IMAGE');
  verifyAssets(CONFIG.videoAssetResources, 'YOUTUBE_VIDEO');
  console.log(JSON.stringify({
    campaign: plan.name, appId: APP_ID, country: country.name, language: 'English',
    currency: context.currency, averageDailyBudget: CONFIG.dailyBudget,
    bidding: CONFIG.targetCpi === null ? 'Maximize installs (no CPI guarantee)' : 'Target CPI',
    targetCpi: CONFIG.targetCpi, startDate: plan.start, endDate: plan.end,
    averageBudgetTimesDays: plan.plannedSpend,
    conservativeExposureBeforeTaxes: plan.conservativeExposure,
    note: 'Average budget x days is NOT a lifetime cap. Daily spend may be up to 2x average.',
    installConversion: conversion ? conversion.resourceName : 'MISSING: configure before creation',
    statusOnCreation: 'PAUSED', headlines: CONFIG.headlines, descriptions: CONFIG.descriptions
  }, null, 2));
  if (CONFIG.targetCpi !== null && CONFIG.dailyBudget / CONFIG.targetCpi < 50) {
    console.log('WARNING: daily budget is below Google\'s recommended 50 x target CPI. ' +
      'Do not invent a lower CPI just to fit this ratio. No budget or bid was changed.');
  }
  if (!CONFIG.imageAssetResources.length || !CONFIG.videoAssetResources.length) {
    console.log('CREATIVE REVIEW: add real app images/video before launch where possible. ' +
      'Google can use store assets and may automatically assemble video. Review generated previews.');
  }
  if (CONFIG.mode === 'PLAN') {
    console.log('PLAN ONLY: no mutation submitted; this is not server-side mutation validation.');
    return;
  }
  check(CONFIG.acknowledgeSpendLimits === true,
    'Read the exposure above, then set acknowledgeSpendLimits=true to create a PAUSED campaign.');
  check(conversion, 'No unique enabled primary Google Play download conversion found. ' +
    'Set up/select SoulBuddy downloads in Goals > Conversions (or begin App campaign setup ' +
    'to generate the download event, then cancel without publishing). Run PLAN again. ' +
    'For manager-owned conversions, configure the campaign in the Google Ads UI instead.');
  const operations = buildOperations(CONFIG, context, plan, country.resourceName,
    language.resourceName, conversion.resourceName);
  const results = AdsApp.mutateAll(operations, {apiVersion: API_VERSION, partialFailure: false});
  check(Array.isArray(results) && results.length === operations.length,
    'Unexpected API result. Inspect Google Ads before retrying; nothing has been enabled.');
  const errors = [];
  results.forEach((result, index) => {
    if (!result.isSuccessful()) errors.push('Operation ' + index + ': ' + result.getErrorMessages().join('; '));
  });
  check(!errors.length, 'Atomic request failed (no requested changes committed):\n' + errors.join('\n'));
  if (AdsApp.getExecutionInfo().isPreview()) {
    console.log('PREVIEW completed. No campaign was persisted. Run once to create it PAUSED.');
  } else {
    console.log('CREATED PAUSED: ' + results[1].getResourceName());
    console.log('Review conversions, dates, budget, country, assets and policy status in Google Ads. ' +
      'Enable it manually only after review. Re-running this installer will not update it.');
  }
}

function validateConfig(c, context) {
  check(['PLAN', 'CREATE_PAUSED'].includes(c.mode), 'Use mode PLAN or CREATE_PAUSED.');
  check(typeof c.expectedCustomerId === 'string' && /^(\d{10}|\d{3}-\d{3}-\d{4})$/.test(c.expectedCustomerId),
    'Fill expectedCustomerId using the account shown above.');
  check(c.expectedCustomerId.replace(/-/g, '') === context.customerId, 'Wrong Ads account; refusing to continue.');
  check(typeof c.expectedCurrency === 'string' && /^[A-Z]{3}$/.test(c.expectedCurrency) &&
    c.expectedCurrency === context.currency, 'Fill expectedCurrency with the exact account currency.');
  check(typeof c.countryCode === 'string' && /^[A-Z]{2}$/.test(c.countryCode), 'Choose one ISO countryCode.');
  toMicros(c.dailyBudget);
  check(Number.isInteger(c.testDays) && c.testDays >= 1 && c.testDays <= 30, 'testDays must be 1-30.');
  check(c.targetCpi === null || (typeof c.targetCpi === 'number' && c.targetCpi > 0),
    'targetCpi must be null or a positive number.');
  if (c.targetCpi !== null) toMicros(c.targetCpi);
  check(typeof c.startDate === 'string', 'startDate must be empty or YYYY-MM-DD.');
  const start = c.startDate || context.today;
  check(/^\d{4}-\d{2}-\d{2}$/.test(start) && validDate(start), 'Invalid startDate.');
  check(start >= context.today, 'startDate is in the past in the Ads account timezone.');
  check(typeof c.campaignKey === 'string' && c.campaignKey.trim() === c.campaignKey &&
    c.campaignKey.length > 0 && c.campaignKey.length <= 100 && !/[\u0000-\u001f\u007f]/.test(c.campaignKey),
    'Use a non-empty campaignKey of at most 100 characters without control characters.');
  check(typeof c.acknowledgeSpendLimits === 'boolean', 'acknowledgeSpendLimits must be boolean.');
  check(typeof c.installConversionResource === 'string' && (!c.installConversionResource ||
    /^customers\/\d+\/conversionActions\/\d+$/.test(c.installConversionResource)), 'Invalid conversion resource.');
  validateText(c.headlines, 30, 'headlines');
  validateText(c.descriptions, 90, 'descriptions');
  [c.imageAssetResources, c.videoAssetResources].forEach(resources => {
    check(Array.isArray(resources) && resources.length <= 20, 'Use 0-20 resources per asset type.');
    check(new Set(resources).size === resources.length, 'Duplicate creative resource.');
    resources.forEach(resource => check(typeof resource === 'string' &&
      new RegExp('^customers/' + context.customerId + '/assets/[1-9][0-9]*$').test(resource),
      'Asset must be an existing resource in this account, not a URL, path or another account\'s asset.'));
  });
  const plannedMicros = toMicros(c.dailyBudget) * c.testDays;
  check(Number.isSafeInteger(plannedMicros * 2), 'Budget is too large to represent safely.');
  const end = addDays(start, c.testDays - 1);
  check(validDate(end), 'End date falls outside the supported calendar range.');
  return {
    name: c.campaignKey + ' | ' + c.countryCode + ' | EN',
    start: start, end: end,
    plannedSpend: plannedMicros / 1000000, conservativeExposure: plannedMicros * 2 / 1000000
  };
}

function buildOperations(c, context, plan, countryResource, languageResource, conversionResource) {
  check(/^geoTargetConstants\/[1-9][0-9]*$/.test(countryResource), 'Invalid country resource.');
  check(/^languageConstants\/[1-9][0-9]*$/.test(languageResource), 'Invalid language resource.');
  check(/^customers\/\d+\/conversionActions\/[1-9][0-9]*$/.test(conversionResource), 'Missing conversion.');
  const prefix = 'customers/' + context.customerId;
  const budget = prefix + '/campaignBudgets/-1';
  const campaign = prefix + '/campaigns/-2';
  const adGroup = prefix + '/adGroups/-3';
  const campaignData = {
    resourceName: campaign, name: plan.name, status: 'PAUSED', campaignBudget: budget,
    advertisingChannelType: 'MULTI_CHANNEL', advertisingChannelSubType: 'APP_CAMPAIGN',
    appCampaignSetting: {
      appId: APP_ID, appStore: 'GOOGLE_APP_STORE',
      biddingStrategyGoalType: c.targetCpi === null ? 'OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST' :
        'OPTIMIZE_INSTALLS_TARGET_INSTALL_COST'
    },
    containsEuPoliticalAdvertising: 'DOES_NOT_CONTAIN_EU_POLITICAL_ADVERTISING',
    startDateTime: plan.start + ' 00:00:00', endDateTime: plan.end + ' 23:59:59',
    geoTargetTypeSetting: {positiveGeoTargetType: 'PRESENCE', negativeGeoTargetType: 'PRESENCE'},
    selectiveOptimization: {conversionActions: [conversionResource]}
  };
  if (c.targetCpi === null) campaignData.maximizeConversions = {};
  else campaignData.targetCpa = {targetCpaMicros: String(toMicros(c.targetCpi))};
  const appAd = {
    headlines: c.headlines.map(text => ({text})), descriptions: c.descriptions.map(text => ({text}))
  };
  if (c.imageAssetResources.length) appAd.images = c.imageAssetResources.map(asset => ({asset}));
  if (c.videoAssetResources.length) appAd.youtubeVideos = c.videoAssetResources.map(asset => ({asset}));
  return [
    {campaignBudgetOperation: {create: {resourceName: budget, name: plan.name + ' | budget',
      amountMicros: String(toMicros(c.dailyBudget)), explicitlyShared: false, deliveryMethod: 'STANDARD'}}},
    {campaignOperation: {create: campaignData}},
    {campaignCriterionOperation: {create: {campaign, location: {geoTargetConstant: countryResource}}}},
    {campaignCriterionOperation: {create: {campaign, language: {languageConstant: languageResource}}}},
    {adGroupOperation: {create: {resourceName: adGroup, campaign, name: 'Faithful daily habits', status: 'ENABLED'}}},
    {adGroupAdOperation: {create: {adGroup, status: 'ENABLED', ad: {appAd}}}}
  ];
}

function chooseConversion(conversions, selected) {
  if (selected) {
    const matches = conversions.filter(conversion => conversion.resourceName === selected);
    check(matches.length === 1, 'Selected conversion is not an enabled primary Google Play download for SoulBuddy.');
    return matches[0];
  }
  return conversions.length === 1 ? conversions[0] : null;
}
function verifyAssets(resources, type) {
  if (!resources.length) return;
  const rows = searchRows('SELECT asset.resource_name, asset.type FROM asset WHERE asset.resource_name IN (' +
    resources.map(gaqlString).join(', ') + ')');
  check(rows.length === resources.length && rows.every(row => row.asset.type === type),
    'An optional asset is missing or has the wrong type: ' + type);
}
function searchRows(query) {
  const iterator = AdsApp.search(query, {apiVersion: API_VERSION});
  const rows = [];
  while (iterator.hasNext()) rows.push(iterator.next());
  return rows;
}
function exactlyOne(rows, description) {
  check(rows.length === 1, 'Could not uniquely resolve ' + description + '. No changes made.');
  return rows[0];
}
function gaqlString(value) {
  return "'" + value.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'";
}
function validateText(values, limit, name) {
  check(Array.isArray(values) && values.length >= 2 && values.length <= 5, name + ': provide 2-5 entries.');
  check(new Set(values).size === values.length, name + ': duplicate text.');
  values.forEach(text => check(typeof text === 'string' && text.trim() === text && text.length > 0 &&
    text.length <= limit && !/[^\x20-\x7e]/.test(text),
    name + ': use non-empty English ASCII text, no newlines, at most ' + limit + ' characters.'));
}
function toMicros(value) {
  check(typeof value === 'number' && Number.isFinite(value) && value > 0, 'Budget/bid must be a positive finite number.');
  const micros = Math.round(value * 1000000);
  check(Number.isSafeInteger(micros) && micros > 0 && Math.abs(value * 1000000 - micros) < 0.00001,
    'Budget/bid must fit an integer number of micros, at most six decimal places.');
  return micros;
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
