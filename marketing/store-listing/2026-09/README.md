# SoulBuddy — Google Play visual assets

Prepared 10 September 2026 for `app.soulbuddy.soulbuddy`, English (United Kingdom), `en-GB`.

## Upload set

| Play Console field | File | Format |
|---|---|---|
| App icon | `upload/en-GB/icon-512.png` | 512 × 512, 32-bit RGBA PNG, under 1 MB |
| Feature graphic | `upload/en-GB/feature-graphic-1024x500.png` | 1024 × 500, 24-bit RGB PNG |
| Phone screenshot 1 | `upload/en-GB/phone-screenshots/01-grow-closer.png` | 1080 × 1920, 24-bit RGB PNG |
| Phone screenshot 2 | `upload/en-GB/phone-screenshots/02-lasting-fruit.png` | 1080 × 1920, 24-bit RGB PNG |

Upload the phone screenshots in filename order. These four files are the listing upload set. This package has not itself been uploaded to Play Console or submitted for release.

The two phone screenshots meet the minimum screenshot count. Google recommends at least four distinct 1080 × 1920 app screenshots for eligibility in certain recommendation formats. This pack deliberately includes only the two latest sanctuary-style captures available. ADB had no connected device at production time. Add fresh prayer, audio-reader, and My Collection captures from the release build before expanding the gallery; older captures show the prior interface.

## Visual direction

Forest green connects the existing launcher identity to luminous ivory and warm gold. The feature graphic depicts a growing olive shoot beside a sunlit stone arch. Its headline is “A daily rhythm with God.” The screenshot headlines are “Grow closer to God.” and “Small seeds. Lasting fruit.”

The icon is an export of the existing approved launcher master, preserving recognition between the Play listing and the installed app. Store assets contain no ratings, awards, testimonials, price claims, or download calls to action.

## Suggested alternative text

- Icon: “SoulBuddy limestone emblem with a gold path of light on forest green.”
- Feature graphic: “SoulBuddy — A daily rhythm with God. An olive shoot grows beside a sunlit stone arch.”
- Phone screenshot 1: “Daily Scripture formation, prayer, and reflection with SoulBuddy.”
- Phone screenshot 2: “Eight orientation Nuggets for spiritual growth and a plentiful harvest.”

## Additional assets

- `brand/soulbuddy-icon-1024.png`: high-resolution app icon master.
- `brand/*.svg`: eight scalable gold symbols for prayer, Scripture, growth, Circles, persons, goals, remembrance, and altars.
- `brand/*-256.png`: transparent PNG exports of the same symbols.
- `visuals/*.jpg`: four reusable sanctuary illustrations from the app: ascent, prayer, Scripture, and renewal. These are supporting artwork, not app screenshots. Do not upload them as screenshots.
- `preview.jpg`: overview of the asset set; do not upload as a screenshot.
- `sources/`: original feature artwork and unmodified device captures.
- `build-assets.cjs`: repeatable layout/export script; accepts `SOULBUDDY_SHARP` as an optional Sharp module path.
- `validation.json`: dimensions, channels, alpha presence, and file sizes of upload assets.
- `checksums.json`: SHA-256 checksums and source provenance.

## Provenance

The feature artwork was generated using the built-in image-generation tool. Its exact prompt is in `sources/feature-prompt.txt`. No API/CLI fallback was used. The final graphic was mechanically resized/cropped by less than 1% to meet Play's exact aspect ratio; its content was not retouched.

The two screenshot sources are physical-device captures from 9 September 2026: `.artifacts/orientation/sanctuary-today-device.png` and `.artifacts/orientation/sanctuary-orientation-device.png`. Android status and navigation bars were cropped away, and the remaining app content was uniformly scaled into editorial layouts. No app controls, text, progress, or features were invented or retouched.

The icon source is `apps/soulbuddy/android/app/src/main/icon/soulbuddy_launcher_master.png`. Supporting illustrations come from `apps/soulbuddy/assets/images/sanctuary/`. The optional line symbols are new editable SVG artwork for marketing use, not replacements for the installed app icon.

## Requirements checked

Google Play preview-asset requirements: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en

Verified on 10 September 2026: 512 × 512 icon under 1024 KB, 1024 × 500 feature graphic without alpha, and two 9:16 phone images without alpha. Additional screenshot copy is confined to the upper 20% of each image. Original device bars and notifications are absent. No phone hardware mockups, store badges, or invented user reviews are included.

This is a phone listing asset package. Tablet and other device-category screenshots require captures of those actual layouts. Play Console content declarations and release submission are separate from the visual assets.
