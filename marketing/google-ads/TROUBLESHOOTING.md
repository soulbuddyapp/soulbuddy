# Install-conversion dependency repair

Revision: `2026-09-17.conversion-order-1`.

## Evidence from the supplied Preview log

On 17 September 2026 at 17:24 (account timezone Africa/Lagos), the diagnostic reported:

- `FULL_INSTALLER` and `CAMPAIGN_AND_PREREQUISITES` failed with `Resource was not found. At campaignOperation.create.selectiveOptimization.conversionActions`.
- The request referred to the newly created action as `customers/7904459880/conversionActions/-4`.
- `WITHOUT_EXPLICIT_CONVERSION_SELECTION` passed with the same bidding, budget, dates and geographic override.
- `WITHOUT_GEO_OVERRIDE` failed at the same conversion-selection field; omitting both optional settings passed.

This isolates the failing reference in that Preview execution. It does **not** establish that every temporary conversion reference fails in the live Google Ads API, nor prove a billing, bidding or geographic fault. The failed criteria, ad group and ad reference a campaign that did not succeed; they are consistent with downstream dependency failures. Their final acceptance still needs validation.

The small `fixtures/temporary-conversion-request.json` is a reduced regression fixture derived from the reported dependency, not an independently runnable campaign request or a full copy of the user's logs.

## Repair

The installer no longer puts a temporary conversion-action ID into campaign selection. Existing eligible SoulBuddy download actions are reused. Otherwise it creates the action in a standalone request, checks Google's returned resource name for a positive ID and correct owner/type, and binds that actual ID before submitting the campaign hierarchy. If the ID is absent, malformed or unreadable, no campaign is submitted. The campaign remains paused and nothing is enabled automatically.

Budget, duration, country, language, bidding, existing conversion-selection rules, image bytes and ad copy are unchanged. Optional-field probe variants have been removed rather than becoming hidden live fallbacks.

## What Preview can and cannot prove

Google states that Preview does not create objects and that dependent reads can behave differently from live execution. See [Preview Mode](https://developers.google.com/google-ads/scripts/docs/preview).

A fresh account therefore gets two simulations: conversion creation, then the **complete campaign structure without explicit conversion binding**. The log ends with `PREVIEW STRUCTURE PASSED. Nothing saved. Install-goal binding remains unvalidated until Run.` A simulated positive or negative conversion ID is never treated as persisted. The actual Run always requires explicit selection of a real action. With an already-existing action, Preview tests that binding too.

This is not an assertion that Preview has verified the untested binding. A real Run is still required for account-side acceptance, and may expose another error. If the campaign request fails, the newly persisted conversion remains; a later Run finds it instead of duplicating it. Earlier successful stages are never described as rolled back by a later atomic rejection.

## Use the corrected installer

Replace all of the older installer in Google Ads Scripts with `ready/SoulBuddy-Ready-to-Run.js`. Do not append it. Preview, inspect the log, then Run the same unchanged file. Check for `SOULBUDDY BUILD 2026-09-17.conversion-order-1` and, after successful live creation, `CREATED PAUSED`.

The `ready/SoulBuddy-Preview-Check.js` variant remains strictly Preview-only for existing diagnostic workflows; Run is a no-op. It uses the same corrected staging logic, not a separate implementation. Do not run simultaneous copies or schedule the installer.

No extra image/video uploads or code configuration are required. Confirm campaign dates, ad previews, install tracking and billing before manual activation.

## Regression coverage and remaining limit

The stateful fake backend refuses a reference to an unpersisted conversion, reproduces the reported failure, and preserves real conversion IDs across simulated reruns. Tests cover first-run setup, existing/manager-owned conversions, partial-stage retention, ambiguous responses, corrupted media, account/currency guards, duplicate campaigns and Preview's refusal to invent persisted IDs. These are offline tests, not a live Google Ads integration run or policy approval.

Google documents using a successful mutation's returned resource name for follow-on work in [Mutate](https://developers.google.com/google-ads/scripts/docs/concepts/mutate). The [App campaign guide](https://developers.google.com/google-ads/api/docs/app-campaigns/create-campaign) describes selective optimization as optional for standard App campaigns. Here it is omitted only in a fresh-account Preview; the live installer preserves explicit install measurement.
