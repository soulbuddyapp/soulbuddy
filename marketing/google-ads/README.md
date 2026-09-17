# SoulBuddy: ready-to-run Google Ads installer

Prepared 17 September 2026 for **790-445-9880**. Replaces the earlier configurable kit. No configuration edits or separate image/video uploads are required.

## Run

Open `ready/SoulBuddy-Ready-to-Run.js` as text. Copy ALL of it into a new script under Google Ads > Tools > Bulk actions > Scripts, inside account 790-445-9880. Authorize, Preview, inspect the log, then Run the same unchanged script. Preview does not persist AdsApp mutations; Run creates PAUSED.[1][2]

Use the generated file, not the shorter `setup-google-ads.js` source template. The long image-data line is necessary. No developer token, external hosting, private-repository access, Drive folder or YouTube channel is needed.

Review the new campaign's settings, ad previews, approval, install tracking, dates and billing; then enable it manually. Nothing starts spending during installation. Do not schedule or run simultaneous copies of this installer. Reruns stop for a same-named pilot (including removed), or another enabled/paused SoulBuddy App campaign. Existing campaigns are never changed or re-enabled.

## Chosen setup

- Android App campaign for `app.soulbuddy.soulbuddy`, Nigeria presence targeting, English.
- Maximize installs without a target CPI; one campaign/ad group, five headlines and descriptions.
- Three embedded transformation images: 1200x628, 1200x1200 and 1200x1500. No video uploads.
- 14 calendar days inclusive, starting on the creation day in the account timezone. Parent campaign PAUSED.

Nigeria is a focused initial market, not a claim of the cheapest CPI. These conservative allowances may produce insufficient learning. No performance, installation count or cost is guaranteed. Maximize installs seeks installations while spending the budget.[3]

The currency is read automatically. These are fixed planning allowances, **not exchange-rate conversions**:

| Currency | Average daily budget | Daily budget x 14 | Conservative 2x-daily exposure over 14 days, before taxes |
| --- | ---: | ---: | ---: |
| USD | 3 | 42 | 84 |
| NGN | 3,000 | 42,000 | 84,000 |
| GBP | 2 | 28 | 56 |
| EUR | 3 | 42 | 84 |
| CAD | 4 | 56 | 112 |
| AUD | 4 | 56 | 112 |

**Daily budget x 14 is NOT a lifetime cap.** Google may spend up to 2x the average budget on a day for most campaigns. The usual unchanged-budget monthly charging limit does not make a shorter test a fixed-total purchase.[4] The last column is conservative arithmetic using that daily limit and unchanged dates/budget, before taxes/fees; other campaigns are excluded. The script sets neither an account spending limit nor a cumulative-spend rule. It never makes payments or enables automatic budget increases. The supplied screenshot showed a balance-exhausted/nearly-exhausted warning: review Billing before activation.

The end date does not move when activation is delayed. Review dates before enabling; subsequent budget/date changes invalidate the arithmetic. An unreviewed account currency stops without mutation and identifies itself in the log, rather than applying an unsafe unit.

## Embedded images and no video uploads

Existing `media/export/images/01-transformation-*.png` ads are converted to RGB JPEG at unchanged dimensions/layout, then embedded in the script. No artwork, UI or copy is regenerated. Source PNG and embedded JPEG hashes appear in `ready/manifest.json`. JPEG bytes can vary across encoder versions; the manifest identifies the actual output.

The script checks JPEG length/signature/SHA-256 before Ads queries or changes. It creates image assets from the embedded bytes and attaches them to the App ad.[5][6] Existing assets with matching content-derived names are reused after type/account/dimension checks. Name-based reuse is not remote cryptographic validation, so inspect the ad previews too.

**No video upload is not a guarantee of image-only delivery.** Google may automatically assemble video from images/store assets; its documentation says App campaign auto-generated videos are not visible in the normal auto-generated-video reporting view.[7] This installer does not claim to disable them and requests no YouTube access. The older optional MP4s remain in the media library but are not required or bundled here.

Screenshots derive from the repository's September 9 device captures. Confirm the Nigerian Play release still matches them. Neither regional Play availability nor UI equivalence has been verified by the installer.

## Automatic install measurement

It reuses one enabled primary Google Play download action for the exact SoulBuddy package and the account's conversion owner. Multiple eligible actions are reduced to the lowest numeric ID, never combined for double counting.

When none exists and this customer owns its conversions, the atomic request creates `GOOGLE_PLAY_DOWNLOAD` / `DOWNLOAD`, primary, default monetary value zero, and selects it for this campaign. Google Play downloads do not require adding Firebase Analytics code.[8][9] Downloads do not measure opens, retention or spiritual progress.

A new primary action is an account-level measurement resource: review other campaigns using account-default DOWNLOAD goals, which may include the new action. No existing conversion action, campaign or goal setting is overwritten. Existing disabled/removed/secondary actions are not silently promoted or duplicated. Visible eligible manager-owned actions can be reused; missing actions are never created under the wrong owner.[10]

Unexpected ownership, disabled measurement or currency conditions stop before mutation with a readable log, not a fallback to unrelated conversion goals. Such account-side issues can require review, but there is no configuration form to fill into the code.

## Safety and verification

One `AdsApp.mutateAll` request with `partialFailure: false` contains the optional new conversion, up to three images, budget, paused campaign, country, language, ad group and ad. A validation rejection commits none of those requested operations.[1] A transport failure can hide a committed paused result: inspect the account before retrying. No blind retry or false success follows an ambiguous response.

No customer/remarketing lists, inferred religious profiles, addiction-based audiences or private prayer/journal data are supplied. Religious content has personalized-advertising restrictions; approval is not guaranteed.[11] The installer does not modify billing, existing campaigns, existing conversions, account-default goals, recommendations or the app. New primary-action implications are described above. This is not an ongoing budget monitor.

Build using Python 3.10+, Pillow 10+, and Node 20+:

```sh
python -m pip install Pillow
python marketing/google-ads/build-ready-script.py
node --check marketing/google-ads/ready/SoulBuddy-Ready-to-Run.js
node --test marketing/google-ads/setup-google-ads.test.cjs
```

The GitHub workflow builds, tests, publishes an artifact and commits the generated script/manifest without app releases or Ads/YouTube uploads. There is one readable implementation, not a separate unmaintained installer.

**51 local tests pass**, including the real generated image bundle, currency budgets, wrong account, new/existing conversions, manager ownership, duplicate campaigns, asset reuse, corruption, paused state, dates, atomic references, Preview and errors. AdsApp is mocked: this is NOT live API/account validation, policy approval or evidence of performance. Run Google's Preview and review the campaign before activation.

## Official references

[1] https://developers.google.com/google-ads/scripts/docs/concepts/mutate

[2] https://developers.google.com/google-ads/scripts/docs/preview

[3] https://support.google.com/google-ads/answer/12073727

[4] https://support.google.com/google-ads/answer/1704443

[5] https://developers.google.com/google-ads/scripts/docs/campaigns/performance-max/assets

[6] https://developers.google.com/google-ads/api/docs/app-campaigns/create-ad-group

[7] https://support.google.com/google-ads/answer/16430641

[8] https://developers.google.com/google-ads/api/docs/conversions/categories

[9] https://support.google.com/google-ads/answer/6255257

[10] https://developers.google.com/google-ads/api/docs/conversions/getting-started

[11] https://support.google.com/adspolicy/answer/143465
