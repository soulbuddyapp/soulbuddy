# Campaign targeting and install-conversion reference repairs

Current revision: `2026-09-17.criteria-names-1`.

## Latest supplied evidence: 18:01 Preview

The user's 17 September 2026 log (Africa/Lagos) reported success for the images, budget, campaign, ad group and ad. Only the location and language criteria failed, both with:

> The field's contents don't match another field that represents the same data. At campaignCriterionOperation.create.resourceName

Both requests referenced `customers/7904459880/campaigns/-2` but omitted their own `resourceName`. The location and language constants were `geoTargetConstants/2566` and `languageConstants/1000`.

The earlier 17:24 log contained the same two resource-name errors, in addition to the independent conversion-selection failure. Treating all the other failures as downstream campaign failures was too broad; this log distinguishes the two targeting defects. Preview success entries do not establish persistence.

## Targeted change

`CampaignCriterion.resource_name` is a composite of customer, campaign and criterion IDs. The new request explicitly provides:

```text
Location: customers/7904459880/campaignCriteria/-2~-5
Language: customers/7904459880/campaignCriteria/-2~-6
Campaign: customers/7904459880/campaigns/-2  (in both entries)
```

The final negative IDs are unique temporary IDs for the two newly created criteria. The country and language constants remain unchanged. A preflight validates matching parents, unique temporary IDs, and the presence of both positive targets. It runs while building the request before a conversion write and again at the campaign mutation boundary.

No targeting is omitted or relaxed in Preview or Run. The same campaign batch remains atomic (`partialFailure: false`); there is no automatic retry or reduced-payload fallback. The paused campaign, install goal, bidding, budget, dates, ad text and embedded image bytes are otherwise unchanged.

This makes the request's two redundant parent representations explicit and consistent. The log does not reveal which implicit resource name Google constructed or identify an internal implementation bug. The local checks enforce the documented name format; they do not prove Google's acceptance of the revised batch.

## Earlier conversion-selection repair remains

The 17:24 diagnostic separately reported `Resource was not found` at `campaignOperation.create.selectiveOptimization.conversionActions`, referring to `conversionActions/-4`. Removing only that selection allowed the isolated campaign to pass; removing only the geographic override did not.

Run now creates a missing SoulBuddy Play-download conversion in a separate request, reads its actual positive resource ID and binds it before campaign creation. A malformed or missing returned ID blocks the campaign. If the campaign request fails, that earlier conversion may remain saved and is reused on a subsequent run.

Fresh-account Preview cannot persist a new conversion, so it tests the campaign structure without that binding and says so. It does include both corrected targeting entries. Existing-conversion Preview tests the real binding as well. No live campaign can be submitted without the real install-goal ID.

## Use

Replace all the older installer text with `ready/SoulBuddy-Ready-to-Run.js`. Verify the first log line contains `2026-09-17.criteria-names-1` and click Preview. Run only after the Preview completes without failed operations. The fresh-conversion success message still says `PREVIEW STRUCTURE PASSED` and explains its binding limitation.

Do not use the Preview Check variant to install; that file refuses live writes. On successful Run, the campaign remains PAUSED. Review previews, Nigeria/English targeting, conversion tracking, dates and billing before manually enabling it. No new media uploads or code edits are required.

## Verification boundaries

The observed criterion requests and error are retained in `fixtures/criteria-resource-name-error.json`. New tests check that the old omitted-name request is rejected by the local preflight, verify exact generated composite names, and exercise missing/mismatched targeting and duplicate-ID cases. These are reference-contract tests, not a reconstruction of Google's server or a live integration result. The existing conversion-order and safety suite remains intact.

Sources:

- [CampaignCriterion resource-name format](https://developers.google.com/google-ads/api/reference/rpc/v25/CampaignCriterion)
- [Temporary resource names and unique negative IDs](https://developers.google.com/google-ads/api/docs/mutating/best-practices)
- [Ads Scripts mutate and result handling](https://developers.google.com/google-ads/scripts/docs/concepts/mutate)
- [Google Ads Preview limitations](https://developers.google.com/google-ads/scripts/docs/preview)
