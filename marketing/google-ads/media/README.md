# SoulBuddy Google Ads media

Prepared 17 September 2026. This completes the earlier script-only campaign kit.

## Upload files

The `export/images/` folder contains nine RGB PNGs: three visual treatments, each
in 1200×628 landscape, 1200×1200 square and 1200×1500 portrait. Every file is under
5 MB. Each is a separately composed layout, not a stretched screenshot.

- `01-transformation`: “Let Christ reshape your life.” Start with these three.
- `02-daily-habits`: “Build faithful daily habits.” An alternate practical message.
- `03-app-first`: existing artwork and the actual interface, with no extra headline.

The `export/videos/` folder contains the same 20-second sound-off ad in 1920×1080,
1080×1080 and 1080×1920. H.264 MP4, 30 fps, baked-in English text, no audio track.
They are crossfaded still-capture ads, **not live screen recordings**. There is no
stock soundtrack, synthetic narration or music license to purchase for these exports.

Use `export/preview.jpg` and the three `export/storyboard-*.jpg` files to review;
do not upload them as ads. `export/manifest.json` records dimensions, checksums,
sizes and provenance. In the downloadable media ZIP, images, videos and previews
are at the package root rather than inside export/.

## Add them to the campaign

In Google Ads, open the paused SoulBuddy App campaign and edit the App ad in its
existing ad group. Upload the three `01-transformation` images under Images.
The other two treatments are alternatives for later comparison; do not create
three separate small-budget campaigns just because three creative sets exist.

For video, upload the MP4s to your own YouTube channel (unlisted or public, with
embedding enabled and no inappropriate age restriction), then add the YouTube
video URLs to the ad. Google documents that App campaign video assets must be
hosted on YouTube. The ZIP itself is not a Google Ads upload format.

Use the headlines/descriptions in the parent campaign kit. Google can combine
those text assets with the images, so inspect previews for redundant wording.
The app-first set is useful when a placement supplies its own headline. No fake
install button, rating, testimonial or Play badge has been drawn into the PNGs.

The earlier installer does **not** upload local media. Its optional
`imageAssetResources` and `videoAssetResources` accept existing asset resource
names after account upload, not file names or YouTube URLs. For an already-created
campaign, edit its ad directly; do not rerun the installer to attach these files.

No assets have been uploaded to Google Ads or YouTube by this package. No campaign
has been enabled, and these files do not demonstrate or guarantee ad performance
or Google approval.

## Provenance and release check

Device captures are the repository's 9 September 2026 Today and Orientation
captures. Only the Android system bars are removed: source crop
`left=0, top=158, width=1280, height=2505`, followed by uniform scaling. The
interface, wording and displayed progress are not reconstructed or retouched.
Some app-first compositions overlap the captured screens as an editorial layout.

The icon and sanctuary artwork are reused from
`marketing/store-listing/2026-09/`. This package generates no substitute app UI.
The supporting religious illustrations are artwork, not photographs or evidence
of a particular spiritual experience. Review all captures against the Play
release before advertising: no current installed-build comparison was possible.

Fonts are rendered into the exports; no font binaries are included or distributed.

## Rebuild

On Ubuntu, install Python 3, Pillow, FFmpeg, fontconfig, P052 (fonts-urw-base35)
and Inter (fonts-inter). From the repository root:

```sh
python3 marketing/google-ads/media/build_media.py \
  --sources marketing/store-listing/2026-09 \
  --output marketing/google-ads/media/export
python3 marketing/google-ads/media/verify_media.py \
  marketing/google-ads/media/export marketing/store-listing/2026-09
```

`--images-only` skips MP4 generation. Source SHA guards deliberately stop the
build when the approved screenshots/icon change; re-review crops before updating
those guards. No network access or advertising credentials are used by the renderer.
The GitHub workflow builds/validates the media and stores the final exports in Git.
Temporary video frames and font binaries are excluded from committed/distributed files.

## Official specifications reviewed

- App campaign assets and YouTube hosting:
  https://support.google.com/google-ads/answer/9948381
- App campaign creative guidance:
  https://business.google.com/in/accelerate/resources/articles/make-better-creative-assets-for-app-campaigns/

Dimensions and file checks are technical validation, not ad-policy approval.
