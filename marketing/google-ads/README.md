# SoulBuddy Google Ads installer

Revision **2026-09-17.persisted-targeting-1** for account **790-445-9880**.
Use the generated `ready/SoulBuddy-Ready-to-Run.js`, not the source template.
No configuration edits, media hosting, developer token or video uploads are required.

## Install

Open the generated file as text, copy ALL its contents into Google Ads > Tools > Bulk actions > Scripts in the specified customer account, and authorize it. Replace the previous installer rather than appending code. Do not schedule it or run concurrent copies.

Use **Preview** first. On a fresh account it explicitly reports:

```
PREVIEW PARTIAL CHECK PASSED. Nothing saved. This is NOT a complete targeting test.
```

This checks the budget/campaign/creative structure. It **does not validate country/language attachment** because this revision attaches them only to a saved campaign ID, and Preview saves no campaign.[1] A missing install conversion binding is likewise deferred. With a matching paused campaign already saved, Preview can validate attachment to that real parent without saving changes. Do not interpret either simulation as proof of live approval or delivery.

After a partial Preview with no failed submitted operations, use **Run on the same unchanged installer** to perform the actual setup. Run creates or reuses a real download conversion, creates a PAUSED parent, attaches Nigeria/English and the image/text ad, then reads the saved settings back. It never enables advertising. Only this final message indicates completed verification:

```
SETUP COMPLETE - PAUSED: customers/7904459880/campaigns/...
```

`PAUSED PARENT CREATED (SETUP INCOMPLETE)` is not completion. Never activate an incomplete parent. Review the final campaign's dates, location/language, previews, policy status, install tracking and billing before manually enabling it. The supplied account screenshot showed a balance warning. The installer does not make payments or change billing.

## Why the targeting path changed

The supplied 19:20 Preview log shows the same `campaignCriterionOperation.create.resourceName` mismatch after explicit negative composite names were added. The previous `criteria-names-1` repair therefore did not resolve it. That log does not expose Google's internal name-resolution mechanism.

This revision follows the ordering in Google's Add App Campaign sample: save the campaign, use its returned resource for location/language criteria, and let Google assign the criterion identity.[2] It does not submit criteria against `campaigns/-2`, supply `campaignCriteria/-2~-5`, or substitute an invented positive campaign ID. Negative IDs remain only for the ordinary parent/creative operations that need references within their own request.

This is a reviewed implementation change, not a claim of account-side success: Google-side acceptance of the new path remains unverified until Run succeeds. The old mock tests that merely required guessed negative criterion names have been replaced by lifecycle and recovery tests. See `TROUBLESHOOTING.md`.

## Settings retained

Android package `app.soulbuddy.soulbuddy`; Nigeria presence targeting; English; Maximize installs without a target CPI; one ad group; five headlines, five descriptions and three embedded images. No customer lists, remarketing, religion-based custom audiences or private prayer/journal data are added. Religious content remains subject to personalized-advertising restrictions and review.[3]

The campaign name remains `SoulBuddy | Android installs | NG | EN | Images v1` so retries find it rather than create another pilot. The duration is 14 inclusive calendar days in the account timezone, starting on creation. Delayed activation does not move the end date. Resuming an incomplete pilot retains its original dates and budget. Expired or modified pilots are not silently extended or overwritten.

The currency is read automatically. The confirmed account is USD; the existing reviewed fallback allowances remain unchanged. These are fixed planning choices, not currency conversions or CPI forecasts:

| Account currency | Average daily budget | Average budget x 14 | Conservative 2x-daily exposure over 14 days, before taxes |
| --- | ---: | ---: | ---: |
| USD | 3 | 42 | 84 |
| NGN | 3,000 | 42,000 | 84,000 |
| GBP | 2 | 28 | 56 |
| EUR | 3 | 42 | 84 |
| CAD | 4 | 56 | 112 |
| AUD | 4 | 56 | 112 |

Average budget x days is **not a lifetime cap**. Google may spend up to twice the average daily budget on a day for most campaigns.[4] The last column is conservative arithmetic with unchanged settings, before taxes/fees and excluding other campaigns. The installer sets no account spending cap or monitoring rule. It never raises a budget or promises cheap installs. A small test can produce too little data to judge performance.

## Staged writes, verification and recovery

There is no transaction covering the entire installation. Each `mutateAll` call uses `partialFailure: false`, but previously successful calls remain saved if a later call fails.[5]

1. Reuse an eligible primary Google Play download action for the exact package, or create one and require its returned positive resource ID. Missing manager-owned actions, disabled/secondary actions and unsupported currencies stop rather than being guessed or overridden.
2. Create the unshared budget and PAUSED campaign together, bound to the real install conversion.
3. Read the saved parent to confirm its expected app, budget, bidding, dates, paused state and install goal. Attach the missing positive Nigeria/English criteria and missing creative in one request, using that saved parent. Criterion IDs/resource names are omitted so Google assigns them.
4. Read the actual targets and ad back. Report completion only when both targets and the expected image/text creative are present on the still-paused pilot.

If stage 3 fails, the parent stays saved and paused; the earlier conversion stays saved too. No automatic cleanup, retry or enabling follows. After inspecting the log, a later run may resume the **same matching paused pilot**, adding only missing targets/creative. Existing matching assets, conversion, budget, group and ad are reused. Different/duplicate targets, exclusions, altered ads, changed budget/bids/dates, expired campaigns, enabled/removed pilots, or another active SoulBuddy campaign prevent automatic repair. No existing resource is updated or removed.

A transport error, an unreadable success resource or incomplete readback is not treated as rollback or readiness. Inspect the account before retrying. Reporting visibility may lag a successful write; this intentionally produces a not-verified result rather than a false completion message. Do not manually edit or enable the campaign while setup is running.

A new primary download action is an account-level measurement resource: review other campaigns using account-default DOWNLOAD goals. No account-default goal is modified. Google Play downloads do not require Firebase Analytics for basic download measurement; downloads are not opens or retention.[6]

## Media

The three existing transformation ads remain embedded: 1200x628, 1200x1200 and 1200x1500 RGB JPEGs, derived from the corresponding repository PNGs. No artwork or UI has been regenerated. Source and JPEG checksums are in `ready/manifest.json`. The script verifies the embedded bytes and reuses existing same-account image assets by content-derived name, type and dimensions. Name-based remote reuse is not a cryptographic check of Google's stored image; review the previews.

No YouTube upload or access is needed. Google may nevertheless automatically assemble video from store/image assets; this is not a guarantee of image-only delivery.[7] The source captures are from 9 September: verify that the released Nigerian Play build still matches their UI and feature claims.

## Build and tests

Python 3.10+, Pillow 10+ and Node 20+:

```sh
python marketing/google-ads/build-ready-script.py
node --check marketing/google-ads/ready/SoulBuddy-Ready-to-Run.js
node --test marketing/google-ads/*.test.cjs
```

The same source generates the installer and optional Preview-only checker; the checker refuses Run. The workflow builds both distributions, tests them, publishes an artifact and commits the verified generated files. It does not deploy the app or execute Google Ads.

The offline suite models persisted parents, criterion assignment, per-request atomicity, retention of earlier stages, safe resume, unchanged dates/budget, failed readback, invalid IDs, duplicate/conflicting resources, no enabling, honest partial Preview and intact embedded images. It is a mock backend, **not live Google API validation or evidence of performance**. The supplied error fixture records an observed failure without claiming to reconstruct Google's internals.

## Official sources

[1] https://developers.google.com/google-ads/scripts/docs/preview

[2] https://developers.google.com/google-ads/api/samples/add-app-campaign

[3] https://support.google.com/adspolicy/answer/143465

[4] https://support.google.com/google-ads/answer/1704443

[5] https://developers.google.com/google-ads/scripts/docs/concepts/mutate

[6] https://support.google.com/google-ads/answer/6255257

[7] https://support.google.com/google-ads/answer/16430641
