# SoulBuddy Google Ads install pilot

Reviewed against Google's public documentation on 17 September 2026. Targets Android package `app.soulbuddy.soulbuddy` using Google Ads Scripts and API v25.

**Nothing in this package starts advertising automatically.** The installer has a read-only PLAN mode and a CREATE_PAUSED mode. Only manually enabling the resulting campaign can start its delivery, subject to approval, dates and account eligibility. This is a campaign setup package, not a promise of low-cost installs or a substitute for account validation.

## Files

- `setup-google-ads.js`: paste this whole file into Google Ads Scripts. No developer token, external hosting, npm dependency or app modification is required.
- `setup-google-ads.test.cjs`: offline safety/contract tests using Node's built-in test runner.
- `README.md`: setup, creative, measurement and spending guidance.

## Proposed first test

Use one Android App campaign for installs, one chosen country, English, one ad group and one coherent creative theme: **Christ-centered transformation through daily habits**. The default pilot window is 14 calendar days. Do not split a small initial budget between multiple countries, campaign objectives and creative themes before collecting useful evidence; this is a testing recommendation, not a country-cost forecast.

The default bid strategy is **Maximize conversions (installs)** with no target CPI. Google seeks installs while spending the budget; this does not promise a particular cost per install.[1] Set `targetCpi` only after obtaining credible account guidance or observed performance. A tiny invented CPI target is not a way to force cheap traffic. Google's target-CPI guidance recommends an average daily budget of at least 50 times the target CPI; this is a recommendation, not a mandatory minimum or performance guarantee.[2]

No default money amount or launch country is supplied. The advertiser must choose both. An illustrative $5/day test is not a claim that $5/day will produce adequate learning in a particular country. If an affordable budget produces too little data, the result is inconclusive, not evidence of success or failure.

App campaigns assemble ads and deliver across Google's supported inventory using your app listing and supplied assets. This is not a Search keyword campaign and does not accept a keyword upload as its targeting strategy.[3]

## Setup

### 1. Prepare the actual advertising account

Open the Google Ads customer account that will pay for the campaign, not a manager-account script context. Complete billing and any required advertiser verification. Confirm the current Play release is publicly installable in the country you choose, and that its listing and app match the ad's feature claims.

Use an **enabled, primary Google Play download conversion for SoulBuddy**. The installer looks up the exact app package and does not create, modify or guess conversion actions. Google documents automatic creation of the Android download event during App campaign construction when one does not already exist; you can begin that UI flow, select SoulBuddy, allow the event to be created, and cancel without publishing.[4] Check it under Goals > Conversions. Google Play downloads do not require adding Firebase Analytics for this initial test.

The current repository's Flutter dependency manifest does not declare Firebase Analytics. No in-app event integration is assumed or added by this package. An install is not proof that a user opened the app, formed a habit or returned.

Manager-owned conversions, third-party install sources and accounts whose conversion actions cannot be read from the current customer are outside this installer's narrow scope. Use Google's UI setup in those cases; do not substitute an unrelated conversion or bypass the guard.

### 2. Paste and configure

Go to **Tools > Bulk actions > Scripts**, create a script, and paste the entire `setup-google-ads.js` file. The Google Ads Scripts editor is the destination, not Google Ads Editor's CSV import. Menu labels can vary; search Google Ads for "Scripts" when necessary. Authorize the script when Google prompts you.[5]

Edit only the CONFIG block initially:

| Setting | Required value |
| --- | --- |
| `expectedCustomerId` | The paying account's 10-digit ID, with or without hyphens. |
| `expectedCurrency` | Exact account currency code. Amounts are never converted. |
| `countryCode` | One uppercase two-letter country code you deliberately choose. |
| `dailyBudget` | A positive number in that account currency, without currency symbols or commas. |
| `startDate` | Optional `YYYY-MM-DD`, in the account timezone; blank means the creation day. |
| `testDays` | 1-30 calendar days, inclusive of the start day; default 14. |

Keep `mode: 'PLAN'`, `targetCpi: null` and `acknowledgeSpendLimits: false` for the first run. The selected country uses presence targeting; the language is English. The script resolves country and language IDs rather than relying on copied numeric location codes.

Run PLAN and read the logs. This is a read-only preflight, **not server-side validation of the mutation payload**. It shows the account identity, resolved location, eligible conversion actions, dates, ad text and spending arithmetic. If multiple matching install conversions exist, set `installConversionResource` to the exact resource of the one you deliberately select, then rerun PLAN. If none exists, complete step 1 first.

### 3. Preview, create paused, inspect, then enable manually

After reviewing the plan and spending limits, set `mode: 'CREATE_PAUSED'` and `acknowledgeSpendLimits: true`. Use Google's **Preview** first. AdsApp mutations in Preview do not persist account changes.[6] Resolve any API, conversion or eligibility error before proceeding.

Run once to create the campaign **PAUSED**. The six dependent operations use one atomic `mutateAll` request with `partialFailure: false`: budget, campaign, country, language, ad group and app ad. A validation rejection should leave none of those requested objects committed.[5]

In the Google Ads UI, review the campaign's app, country/presence setting, language, dates, budget, install conversion, bids, ad previews and policy status. Add or review real screenshots and a video. Confirm that the proposed text is accurate for the released app. Only then enable the campaign manually. Ad group/ad status is enabled beneath the paused parent so parent activation can serve the intended ad; the script never enables the parent.

A campaign created today with a 14-day window still ends 14 calendar days from today even if you enable it later. Set future dates before creation or adjust them in the UI after review. Do not let a paused review period consume the intended learning window unnoticed.

Do not schedule this installer to repeat. Rerunning stops if the same campaign name exists, including paused or removed campaigns; it never updates/re-enables that campaign. Run only one copy at a time. Different campaign keys create separate campaigns, and simultaneous independently configured copies are not coordinated. Inspect the account after an ambiguous transport error before retrying.

## Spending: read before enabling

An average daily budget is **not a hard daily cap**. Google can spend up to twice the average daily budget on a day for most campaigns. The usual monthly charging limit is 30.4 times an unchanged average daily budget; that does not turn a shorter campaign into a fixed-lifetime-budget purchase.[7]

For illustration only, at $5/day for 14 days:

- `$5 x 14 = $70` is average-budget arithmetic, **not a guaranteed $70 maximum**.
- A day may spend up to $10.
- `$5 x 2 x 14 = $140` is a conservative campaign-window exposure estimate before applicable taxes/fees, assuming the same budget and dates and the stated daily limit.

The script prints both the average-budget arithmetic and the conservative exposure. It does not create an account-level spending limit, purchase prepaid credit, apply a lifetime campaign cap or pause on an accumulated-spend threshold. Reporting and automated-rule delays mean a threshold rule should not be represented as an exact cap either.

Do not enable account rules, recommendations or other tools that increase the pilot budget automatically. Review spend daily. Pausing stops future serving; it does not undo accrued charges. For a strict total allowance, leave room for possible overdelivery and taxes, lower the daily amount accordingly, and confirm account-specific billing controls before launch. Budget or date changes invalidate the original arithmetic.

## Included text assets

All five headlines are at most 30 characters and all five descriptions at most 90. They can be combined independently; they do not assume a sequence.[8]

| Headline | Characters |
| --- | ---: |
| Let Christ Reshape Your Life | 28 |
| Build Faithful Daily Habits | 27 |
| Put Your Faith Into Practice | 28 |
| Prayer, Scripture & Reflection | 30 |
| Grow in Christ, Day by Day | 26 |

Descriptions:

1. Let Christ reshape everyday life through prayer, Scripture and small, faithful actions.
2. Choose a personal goal. Build habits of prayer, reflection, forgiveness and love.
3. Keep a prayer journal, set reminders and put your faith into practice each day.
4. Begin with one faithful step. Pray, reflect and grow in the life you already have.
5. Move beyond good intentions. Cultivate daily habits rooted in Christ.

The text invites the user into a practice; it does not claim the app guarantees transformation, infer an individual's religion or announce that the viewer has a personal struggle. More figurative Kingdom/cross language can remain in the store narrative while the short ad explains the practical mechanism.

### Images and video

The installer works with text plus assets Google may source from the store. That is a setup starting point, not a claim of optimal creative coverage. Review automatically generated previews, especially any assembled video.[3][8]

Prefer authentic current app screens. Existing repository assets are under `marketing/store-listing/2026-09/`; confirm they still match the released UI. Recommended optional image sizes are 1200x1200, 1200x628 and 1200x1500. Google's listed formats are PNG/JPG with a 5 MB maximum.[8] Do not stretch a Play feature graphic into every ad format.

A proposed 20-second real-screen recording:

| Time | Actual interface action | Overlay |
| --- | --- | --- |
| 0-4 s | Open Today with a concrete daily action. | Let Christ reshape your life. |
| 4-9 s | Choose a personal goal and relevant prayer. | Begin with one faithful habit. |
| 9-15 s | Show Scripture, a reminder or a reflection. | Pray. Reflect. Put faith into practice. |
| 15-20 s | Return to Today, then app name and install prompt. | SoulBuddy. Your next faithful step. |

Use only screens and capabilities included in the release, with fictional/non-sensitive journal content. No user confession, private prayer or identifying personal information should appear. Upload video to YouTube and add it through the campaign's asset interface. You may alternatively populate `imageAssetResources` / `videoAssetResources` with already-uploaded Google Ads asset resource names from the same account. These are not local file paths, public image URLs or raw YouTube IDs.

## Religious-content and privacy safeguards

Google treats religious beliefs/guidance as a sensitive-interest category for personalized advertising. That does not amount to a blanket ban on advertising a prayer app. It restricts the audience tools that may be used.[9][10]

This installer adds no customer lists, remarketing lists, religion-based custom audiences, lookalikes, inferred-belief signals or addiction-based targeting. It uses country and language settings only. Do not add user lists derived from app usage, church membership, prayer requests or journal entries. Do not pass goals, private text, confessions or inferred religious profiles into ad-event parameters. The script cannot certify Google's eventual approval: the destination, creative and account are still subject to review.

## Evaluate results without confusing cheap installs with growth

Before launch, verify one real installation/opening journey, onboarding, one prayer/goal action and a return visit on the release build. This manual product check is independent of ad attribution.

During the first days, inspect approval, delivery, spend and conversion reporting. Avoid repeatedly changing budgets, bids and assets in response to a few installs. Google describes an initial learning/stabilization period of roughly 7-14 days for App campaigns; sparse data can require longer.[2] This does not prevent pausing for a budget, policy or broken-product problem.

Review installs and cost per install, but do not call the pilot successful solely because downloads are cheap. The meaningful next question is whether acquired users begin and return. The package does not instrument activation or retention. Design privacy-respecting, consent-appropriate measurement separately before using deeper events for optimization. Do not export spiritual or personal content to obtain attribution.

## Validation and limitations

Run locally with Node 20+:

```sh
node --check setup-google-ads.js
node --test setup-google-ads.test.cjs
```

52 offline tests pass, covering required account/budget inputs, money conversion, creative limits, invalid dates, account-timezone date handling, primary install selection, optional asset validation, duplicate prevention, atomic request shape, paused creation, preview logging and error paths. Tests mock AdsApp: they do not execute Google's live API, validate account eligibility, certify ad approval, or demonstrate campaign performance.

The account has not been connected or accessed for this package. No campaign or ad spend has been created by preparing these files. Google Ads Preview and account review remain necessary. API v25 is explicitly pinned to the reviewed documentation; do not switch versions blindly if a future account/runtime rejects it. Use the UI App promotion > App installs flow with the same settings and text as a fallback.

## Official sources

[1] [App campaign bidding strategies](https://support.google.com/google-ads/answer/12073727)

[2] [App campaign optimization guidance](https://support.google.com/google-ads/answer/6167156)

[3] [About App campaigns](https://support.google.com/google-ads/answer/6247380)

[4] [Create an App campaign for installs](https://support.google.com/google-ads/answer/12575501)

[5] [Google Ads Scripts mutate and atomic operations](https://developers.google.com/google-ads/scripts/docs/concepts/mutate)

[6] [Google Ads Scripts preview](https://developers.google.com/google-ads/scripts/docs/preview)

[7] [Average daily budgets and spending limits](https://support.google.com/google-ads/answer/1704443)

[8] [App campaign assets](https://support.google.com/google-ads/answer/9948381)

[9] [Personalized advertising policy](https://support.google.com/adspolicy/answer/143465)

[10] [Religious beliefs in personalized advertising](https://support.google.com/adspolicy/answer/16701958)

[11] [App campaign API creation](https://developers.google.com/google-ads/api/docs/app-campaigns/create-campaign)

[12] [App campaign ad groups and ads](https://developers.google.com/google-ads/api/docs/app-campaigns/create-ad-group)

[13] [API v25 install bidding goals](https://developers.google.com/google-ads/api/reference/rpc/v25/AppCampaignBiddingStrategyGoalTypeEnum.AppCampaignBiddingStrategyGoalType)

[14] [API v25 campaign fields and date-time settings](https://developers.google.com/google-ads/api/reference/rpc/v25/Campaign)

[15] [API v25 conversion action fields](https://developers.google.com/google-ads/api/reference/rpc/v25/ConversionAction)
