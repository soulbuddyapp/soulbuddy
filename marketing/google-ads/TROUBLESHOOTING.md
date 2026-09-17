# Diagnose the Google Ads campaign rejection

The reported Changes entries show a failure at campaign creation followed by failures of the dependent location, language, ad group and ad. The supplied text does **not** contain a specific Google Ads validation code. No root cause is confirmed. Do not interpret the balance warning as that code, change bidding speculatively, or delete resources based solely on the Changes view.

## One unchanged file, Preview only

Use `ready/SoulBuddy-Preview-Check.js`, not the installer. Paste the entire generated file into a new Google Ads script in account 790-445-9880, authorize if asked, and click **Preview**. Open the execution's **Logs / log statements**, not **Changes**, and copy the block between:

```
=== SOULBUDDY DIAGNOSTIC BEGIN ===
...
=== SOULBUDDY DIAGNOSTIC END ===
```

If the account preflight stops before that block, copy its `SOULBUDDY SCRIPT ERROR` or existing-campaign message instead. Do not edit any configuration or upload images/videos. The three existing images are already embedded. This diagnostic is **not an installer or a confirmed fix**: clicking Run exits before account reads or mutations. An additional guard checks Preview at the mutation boundary.

## What it checks

It submits the unchanged installer request to Google Preview and prints `getErrorMessages()` individually beside each operation type. This is the documented error surface; if Google still supplies a generic message, the script preserves it rather than inventing a code. It does not print image bytes, access tokens or raw requests. Individual messages and message counts are bounded; unusually long data is redacted.

Only if the full request gives a complete, inspectable campaign failure, the Preview-only file tries a bounded diagnostic sequence: campaign plus prerequisites; then the same isolated request without explicit conversion selection; without the geographic-presence override; and without both optional settings. Each request independently defines its temporary resources. The script stops early when the isolated request passes, or after an exception, incomplete response or uninspectable result. At most five Preview batches are submitted including the original.

These are controlled comparisons, **not fallback campaigns**. The original request is not changed. No variant can be submitted by the normal installer. No bid, budget, duration, app ID, ad copy or live geographic targeting changes are made. Passing a reduced request is evidence to investigate an interaction, not proof of its cause. Never take the reduced request and launch it without a reviewed fix.

Google Preview simulates AdsApp changes and does not save them. It is not equivalent to a validated live transaction; Google's documentation explicitly warns that code relying on newly created objects can behave differently in Preview. A successful Preview does not certify account eligibility or a subsequent live execution. The diagnostic uses no external email, Drive, HTTP or other side-effecting service.

The normal `SoulBuddy-Ready-to-Run.js` has the same original campaign payload and improved operation-level logs. It still creates PAUSED only. Do not use it for another live attempt just because a reduced diagnostic probe passes. No campaign failure has been claimed fixed by this diagnostic update.

## Validation and references

The existing installer tests remain; `diagnostics.test.cjs` adds 19 offline regression tests for accidental Run protection, all probe paths, preserved bidding/budgets/dates, ambiguous results, original-request immutability, logging and both generated distributions. These use mocked AdsApp responses, not a live Ads account.

- MutateResult error interface: https://developers.google.com/google-ads/scripts/docs/reference/adsapp/adsapp_mutateresult
- Preview and its limitations: https://developers.google.com/google-ads/scripts/docs/preview
- Atomic requests: https://developers.google.com/google-ads/scripts/docs/concepts/mutate
- Temporary negative resource IDs: https://developers.google.com/google-ads/api/docs/mutating/best-practices
- Current bidding compatibility (standard MaximizeConversions includes App campaigns): https://developers.google.com/google-ads/api/docs/campaigns/bidding/strategy-types
