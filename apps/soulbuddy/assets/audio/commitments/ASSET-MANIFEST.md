# Commitment media manifest

All spoken words are static public copy from the approved Commitment design and plan. No personal prayer, calling, need, practice, declaration, or other private user content was read or sent to a provider.

Regenerate with `powershell -NoProfile -ExecutionPolicy Bypass -File tools/audio/generate_commitment_assets.ps1`. Requires Python, edge-tts, ffmpeg, ffprobe, curl.exe, internet access, and the explicitly selected Microsoft en-US-JennyNeural voice. A failed voice request aborts; there is no substitute or silent placeholder.

## Playback and captions

WAV masters are mono PCM16 at 24 kHz. Generic foreground narration defaults to 0.85x; notification playback and music use 1.0x. Sentence cues use source media milliseconds, so players use reported media position directly. Guides end with “Now listen.” The common opening’s closing sentence is moved after the guide-specific paragraph to preserve the guide/bell/timer handoff. The design’s “You do not carry this alone” supersedes the plan’s one-word invitation discrepancy.

Narration is normalized to -19 LUFS with a -2 dBTP target. Guides and Listening have approximately 55 seconds of source media (64.7 seconds at 0.85x). Microsoft neural TTS is the production voice, replacing the plan’s optional/prototype desktop Zira voice. Provider sentence boundaries are scaled by the exact tempo used for the finished recording. No artificial silence is used to imitate a spoken guide.

Signal verification checks decoding, duration, format, measured loudness, clipping, transcript coverage, and platform-copy identity. Human listening review remains pending; automated checks do not establish aesthetic quality or editorial approval of a recording.

## Music rights and changes

“Aphelion” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au

Official source: https://www.scottbuckley.com.au/library/aphelion/

Official MP3: https://www.scottbuckley.com.au/library/wp-content/uploads/2026/04/Aphelion.mp3

License: https://creativecommons.org/licenses/by/4.0/

Exact source interval: **00:01:45–00:02:15** (105–135 seconds). Changes: extract this interval, apply an 0.8-second fade in and a 1.5-second fade out, encode stereo MP3 at 192 kbps. The downloaded full track is kept only in a temporary directory and removed automatically. Include the credit and a link to the official source in app credits.

## Narration and Scripture provenance

SoulBuddy owns its editorial guidance; the synthetic recordings use Microsoft Edge neural TTS through edge-tts. This manifest does not grant additional Microsoft service rights or assert ownership of Microsoft voices. Psalm 46:10 is quoted from the existing SoulBuddy RSVCE Scripture source and retains its existing distribution conditions. Source text: `docs/superpowers/plans/2026-09-24-commitment-formation-journey.md` and the approved design.

## Files

| Asset ID | File | Duration (s) | Format | SHA-256 |
|---|---|---:|---|---|
| readiness_v1 | readiness_v1.wav | 63.363 | pcm_s16le | `e68d384aafa43278c7e55ff4b1b1993bb9b59a414bcc243b6637df40b9c6ba12` |
| invitation_v1 | invitation_v1.wav | 21.603 | pcm_s16le | `a47da4d18eb70ae4adad40ecbf72cc932138e7c0eabaaffcca63e3ebb02b1125` |
| guide_surrender_v1 | guide_surrender_v1.wav | 54.974 | pcm_s16le | `707e42299644c38e1a1299a91263e7d3ba5695369a7c58b221d66536d2798fd4` |
| guide_direction_v1 | guide_direction_v1.wav | 54.978 | pcm_s16le | `5feb4502342a740932b52f9c495fa8f18586fc046b8f71bfcd52b70571b52a21` |
| guide_peace_v1 | guide_peace_v1.wav | 54.977 | pcm_s16le | `fe0c0879582d4936d8c79ebea7a011155837bb08eeef2c051b0c4152da49bf6b` |
| listening_v1 | listening_v1.wav | 54.967 | pcm_s16le | `059fad49b5ac357609b223265f9d39605adbc161348cb0e052d37278b787e85e` |
| spoken_invitation_v1 | commitment_invitation_v1.wav | 6.219 | pcm_s16le | `ac589e2811d2346a74fca7d4362d27ed20a1cf4ab3220271dbcb2152630873e3` |
| aphelion_excerpt_v1 | aphelion_excerpt_v1.mp3 | 30.000 | mp3 | `0cf52084be3a4d937ccdfa6a636ef51e63cb6588a325780c3e931877b1ab2406` |

Every media file is optional at runtime: narration falls back to its complete transcript; music falls back to silence. Notification fallback is a silent generic notification. Platform sound copies are byte-identical to the master and use the versioned name `commitment_invitation_v1.wav`. The catalog contains full caption/transcript checksums, source checksum, detailed provenance, and per-asset duration bounds.
