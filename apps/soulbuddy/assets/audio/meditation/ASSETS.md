# SoulBuddy meditation sound beds

These restrained offline beds are aids to attention. They are not presented as
treatments, frequencies, or spiritual effects. The two original masters below are 60-second,
44.1 kHz mono MP3 loops encoded at 64 kbps. They were deliberately attenuated
for use beneath spoken prayer.

## `stillness.mp3`

- Origin: original procedural brown-noise master generated for SoulBuddy.
- Rights: SoulBuddy project original; no third-party audio source.
- Recipe: FFmpeg `anoisesrc`, deterministic seed `26371`, 70 Hz high-pass,
  3.2 kHz low-pass, -10 dB gain, and a 10-second equal crossfade loop seam.
- SHA-256: `515C7C4095342F57C8B342BFE49FBC74218F2EAF7C886C128E25FAA53450CA20`

## `flowing_water.mp3`

- Origin: `romo-StreamAmbientROMO52516BlackCanyonTrailFinal1.mp3`, recorded by
  J. Job for the U.S. National Park Service, Rocky Mountain National Park.
- Source page: <https://www.nps.gov/romo/learn/photosmultimedia/sounds-ambient-soundscapes.htm>
- Rights: U.S. National Park Service public-domain recording.
- Local source used: the audited copy already retained by the Elbiblio app as
  `ambient/ambient-today.mp3`.
- Recipe: 60-second selection, 100 Hz high-pass, 8 kHz low-pass, -7 dB gain,
  mono conversion, and a 10-second equal crossfade loop seam.
- SHA-256: `CEE193709B95A504D1E9DD3771984A81F75A12A9B08EDDF67AF423C3B7314A6B`

Before a release build, audition both files on a phone speaker, wired or
Bluetooth headphones, and in a quiet room. Reject any later replacement that
contains speech, abrupt transients, clipping, or an obvious loop seam.

## Licensed instrumental recordings (replaced 2026-09-26)

The five motivational filenames now contain excerpts of five distinct finished
compositions by **Scott Buckley**, downloaded from the official library links
below. They replace the former procedural sine-pad approximations. These are
professionally composed instrumental recordings; the source descriptions include
piano, sampled/orchestral strings and synth. We do not claim live acoustic-only
performances. Stable filenames preserve existing preferences; picker labels use
the original titles.

All five works are **Creative Commons Attribution 4.0 International**:
<https://creativecommons.org/licenses/by/4.0/>. The official track pages explicitly
permit commercial use with attribution. Artist guidance:
<https://www.scottbuckley.com.au/library/licensing/>. No endorsement is implied.
Display each title, Scott Buckley, the artist website, license link and adaptation
notice in the app's music credits. Retain these credits with redistributed media.

| Stable filename | Picker title | Selected character |
| --- | --- | --- |
| hopeful_piano.mp3 | Resolutions | Gentle piano with hopeful strings |
| cinematic_rise.mp3 | Aurora | Slow, warm orchestral ambience before its later climax |
| steady_resolve.mp3 | Affirmations | Reflective piano, strings and a repeating pulse |
| warm_strings.mp3 | First Snow | Gentle piano, strings and clarinet |
| victorious_calm.mp3 | A Kind Of Hope | Reflective piano and string/synth support |

### Editing and verification

Source bounds and final decoded durations are in the manifest below. The selected
passages precede the later large crescendos; no drums or trailer impacts were added.
Eight seconds of the excerpt's tail are blended with its first eight seconds using
complementary cosine weights (w = (1 - cos(pi*t))/2). The file begins at source
start + 8 seconds, continues through the body, then ends with the blend. Its end
therefore joins the next repetition at a continuous position in the original
recording. This overlap reduces each selected passage by eight seconds. Candidate
boundaries were chosen for similar pitch-class energy and level; this is an
engineering aid, not a substitute for a musical listening review.

Processing: decode the source selection to 44.1 kHz stereo float PCM; overlap as
above; FFmpeg two-pass loudnorm with I=-20, TP=-2, LRA=7, first-pass measured values
and linear=true; encode using libmp3lame at 128 kbps and 44.1 kHz. Original tempo and
pitch are preserved. Artist, original title, license URL and edit notice are
embedded in ID3 tags. Players must honor MP3 gapless metadata; device playback
remains the final check for platform-specific repeat gaps.

Run python scripts/commitments/verify_meditation_music.py (NumPy, FFmpeg and
FFprobe required). It checks all pinned SHA-256 hashes, five distinct source
records, official source/license URLs, attribution, adaptation notices, full
MP3 decode, duration, active stereo signal, spectral concentration, decoded repeat
boundary, integrated loudness and true peak. Run regression checks with
python -m unittest discover -s scripts/commitments -p test_verify_meditation_music.py.
Signal checks do not prove authorship or aesthetic suitability: the official source
provenance is the evidence that these replace the procedural placeholders.
Automated checks are not a claim of listening on headphones or phone speakers.

Engineering gain rationale: a -20 LUFS master played at gain 0.22 receives
20*log10(0.22) = -13.15 dB attenuation, yielding approximately -33.2 LUFS
(-33.6 after encoding in these files), about 14.6 dB below narration at -19 LUFS.
This is a level-budget calculation, not a subjective/device audition. The earlier
-26 LUFS masters with gain 0.16–0.20 would have been around -40 to -42 LUFS.

Measured packaged audio (2026-09-26):

| Title | Decoded duration | Integrated LUFS | True peak dBTP |
| --- | --- | --- | --- |
| Resolutions | 108 s | -20.50 | -5.56 |
| Aurora | 108 s | -20.53 | -7.13 |
| Affirmations | 98 s | -20.44 | -7.12 |
| First Snow | 100 s | -20.44 | -5.91 |
| A Kind Of Hope | 106 s | -20.40 | -2.44 |

The following JSON is the authoritative machine-readable provenance manifest.
Source hashes identify the full official downloads; asset hashes identify the
edited files packaged by SoulBuddy. Retrieved 2026-09-26.

<!-- licensed-music-manifest -->
```json
[
  {
    "file": "hopeful_piano.mp3",
    "title": "Resolutions",
    "artist": "Scott Buckley",
    "license": "CC BY 4.0",
    "license_url": "https://creativecommons.org/licenses/by/4.0/",
    "source_page": "https://www.scottbuckley.com.au/library/resolutions/",
    "source_url": "https://www.scottbuckley.com.au/library/wp-content/uploads/2022/01/Resolutions.mp3",
    "source_sha256": "d61702c3b378662a3dd07d6207d9ac2cfedd405a4746c273db890afa644c7015",
    "source_duration_seconds": 327.907687,
    "sha256": "44f4e5edc9aef02dacfb31892dee2764dfbbb092176c38b1e1646925943ab760",
    "excerpt_start_seconds": 42,
    "excerpt_end_seconds": 158,
    "duration_seconds": 108,
    "crossfade_seconds": 8,
    "changes": "Excerpted; 8-second cosine overlap at loop boundary; loudness normalized to -20 LUFS; encoded as 44.1 kHz stereo MP3 at 128 kbps.",
    "credit": "“Resolutions” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au",
    "retrieved": "2026-09-26"
  },
  {
    "file": "cinematic_rise.mp3",
    "title": "Aurora",
    "artist": "Scott Buckley",
    "license": "CC BY 4.0",
    "license_url": "https://creativecommons.org/licenses/by/4.0/",
    "source_page": "https://www.scottbuckley.com.au/library/aurora/",
    "source_url": "https://www.scottbuckley.com.au/library/wp-content/uploads/2021/10/Aurora.mp3",
    "source_sha256": "311ae35bf827be51372da47693357f79b8022b704d833cd26d547bbf67c117ed",
    "source_duration_seconds": 498.767483,
    "sha256": "b60093b34ef64e26edec101ec3150a39fb730dde0a9af923fd811ec5827d1bf7",
    "excerpt_start_seconds": 30,
    "excerpt_end_seconds": 146,
    "duration_seconds": 108,
    "crossfade_seconds": 8,
    "changes": "Excerpted; 8-second cosine overlap at loop boundary; loudness normalized to -20 LUFS; encoded as 44.1 kHz stereo MP3 at 128 kbps.",
    "credit": "“Aurora” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au",
    "retrieved": "2026-09-26"
  },
  {
    "file": "steady_resolve.mp3",
    "title": "Affirmations",
    "artist": "Scott Buckley",
    "license": "CC BY 4.0",
    "license_url": "https://creativecommons.org/licenses/by/4.0/",
    "source_page": "https://www.scottbuckley.com.au/library/affirmations/",
    "source_url": "https://www.scottbuckley.com.au/library/wp-content/uploads/2021/06/sb_affirmations.mp3",
    "source_sha256": "1e149a846f68407cf3a6f4afa16624244be718430f250ff0ada51a0ca2e2621b",
    "source_duration_seconds": 301.722585,
    "sha256": "233ba220506a6ea740fe7189b8b5e344d7f8e9f1a4fa2a19d53ec0cf506fa2f1",
    "excerpt_start_seconds": 48,
    "excerpt_end_seconds": 154,
    "duration_seconds": 98,
    "crossfade_seconds": 8,
    "changes": "Excerpted; 8-second cosine overlap at loop boundary; loudness normalized to -20 LUFS; encoded as 44.1 kHz stereo MP3 at 128 kbps.",
    "credit": "“Affirmations” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au",
    "retrieved": "2026-09-26"
  },
  {
    "file": "warm_strings.mp3",
    "title": "First Snow",
    "artist": "Scott Buckley",
    "license": "CC BY 4.0",
    "license_url": "https://creativecommons.org/licenses/by/4.0/",
    "source_page": "https://www.scottbuckley.com.au/library/first-snow/",
    "source_url": "https://www.scottbuckley.com.au/library/wp-content/uploads/2022/12/FirstSnow.mp3",
    "source_sha256": "47650ff7ccc573df011a11d8440eb8c79e30fae31f61fc72750545efd41f6686",
    "source_duration_seconds": 213.358435,
    "sha256": "2c6ed4fbdc4661df8a9ff65bc5a6669759289ce1871fc706b74402ac18b91afe",
    "excerpt_start_seconds": 24,
    "excerpt_end_seconds": 132,
    "duration_seconds": 100,
    "crossfade_seconds": 8,
    "changes": "Excerpted; 8-second cosine overlap at loop boundary; loudness normalized to -20 LUFS; encoded as 44.1 kHz stereo MP3 at 128 kbps.",
    "credit": "“First Snow” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au",
    "retrieved": "2026-09-26"
  },
  {
    "file": "victorious_calm.mp3",
    "title": "A Kind Of Hope",
    "artist": "Scott Buckley",
    "license": "CC BY 4.0",
    "license_url": "https://creativecommons.org/licenses/by/4.0/",
    "source_page": "https://www.scottbuckley.com.au/library/a-kind-of-hope/",
    "source_url": "https://www.scottbuckley.com.au/library/wp-content/uploads/2022/10/AKindOfHope.mp3",
    "source_sha256": "d0dc554c0db9ea208b4f59e4f0c1b4446aa7ef622c7bfeffca278130a46c51f1",
    "source_duration_seconds": 342.600544,
    "sha256": "d364001c6a22bfe21fff72f258a308da37ccbe48edc0c920639d614662222821",
    "excerpt_start_seconds": 30,
    "excerpt_end_seconds": 144,
    "duration_seconds": 106,
    "crossfade_seconds": 8,
    "changes": "Excerpted; 8-second cosine overlap at loop boundary; loudness normalized to -20 LUFS; encoded as 44.1 kHz stereo MP3 at 128 kbps.",
    "credit": "“A Kind Of Hope” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au",
    "retrieved": "2026-09-26"
  }
]
```

## Unchanged synthetic nature approximations

The six files gentle_rain.mp3, ocean_waves.mp3, forest_morning.mp3, soft_wind.mp3,
warm_fireplace.mp3 and night_crickets.mp3 remain original **procedural
approximations**, generated by scripts/generate_meditation_soundscapes.py from
filtered noise, modulated envelopes and synthesized chirps/crackles. They are not
field recordings of actual rain, ocean, forest, wind, fire or insects. No
third-party recordings were used. The generator now owns only these six files
and cannot overwrite licensed music. Their audio bytes were not changed in this
replacement.
