# Targeting repair: observed evidence and validation limits

## Observed user logs, 17 September 2026

The original batch failed to resolve `selectiveOptimization.conversionActions` when it referenced a new temporary conversion. Separating conversion creation and using its real returned ID removed that failure from the next structural Preview. The conversion binding still requires live validation on a fresh account.

At 18:01, `conversion-order-1` passed the image, budget, campaign, ad-group and ad operations, but both location and language failed with:

```
The field's contents don't match another field that represents the same data.
At campaignCriterionOperation.create.resourceName
```

At 19:20, `criteria-names-1` produced the same two errors despite explicitly supplying `campaignCriteria/-2~-5` and `campaignCriteria/-2~-6`. That proposed repair did not work. The remaining operations again reported Preview success. These are simulated operation results, not evidence of saved account resources.

The error identifies a resource-name conflict but does not expose the internal inferred/resolved values or prove that all temporary-ID use is unsupported. No exact undocumented Google-internal cause is asserted here.

## Current change

`2026-09-17.persisted-targeting-1` no longer relies on that failing temporary-parent path. It saves the paused campaign first and uses Google's returned positive campaign resource for a later targeting request. It omits criterion resourceName and criterionId entirely. This follows the lifecycle and criterion construction in Google's Add App Campaign sample:

https://developers.google.com/google-ads/api/samples/add-app-campaign

Both Nigeria and English remain required. The installer does not launch a wider campaign or reduce targeting to obtain a passing result. Budget, bidding, duration, copy and image bytes are unchanged.

## Preview is explicitly partial before a parent exists

Google Preview saves no parent. Consequently, fresh Preview validates parent and creative structure but does not submit targeting against a fake/new campaign ID. It says `TARGETING: DEFERRED, NOT VALIDATED BY GOOGLE` and `PREVIEW PARTIAL CHECK PASSED`, not full setup success. A missing conversion binding is also deferred. These limits cannot be erased by locally invented IDs or mocked tests.

Run is needed to save a real paused parent, attach targets to it and inspect the resulting state. A Preview performed after a partial Run can validate attachment against that actual saved parent without changing it. The optional diagnostic file itself never performs live writes.

## Completion and interrupted setup

Only `SETUP COMPLETE - PAUSED` (or `ALREADY CONFIGURED AND PAUSED` on a verified rerun) means the installer read back the expected campaign, install goal, country, language and creative. It does not mean policy approval, billing readiness or actual delivery.

On a failure after the parent stage, the parent and conversion remain saved. Keep the campaign paused. The final target/creative batch is atomic per request, not a rollback of the earlier stages. The installer can resume the same matching paused pilot without resetting its dates or creating a duplicate. It will not overwrite conflicting targets, edited creative, changed budgets/bids/dates or enabled/removed campaigns. There is no automatic retry after transport errors.

An incomplete readback may reflect eventual visibility or a genuine mismatch. In either case it is not treated as success. Inspect the existing campaign and logs before rerunning. Do not delete resources or rename the campaign solely to bypass the safety check.

## Verification status

Local tests model the observed failure and the new staged lifecycle; they do not reproduce Google's backend. The next account-side Run is still needed to establish whether Google accepts the revised target request. No current source claims otherwise.
