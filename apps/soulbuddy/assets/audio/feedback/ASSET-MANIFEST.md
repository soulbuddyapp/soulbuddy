# SoulBuddy feedback tones

Generated specifically for SoulBuddy on 2026-08-12 by the deterministic
`tools/audio/generate_soulbuddy_tones.dart` script. These original synthesized
tones are dedicated under **CC0-1.0**. They do not contain or derive from the
Elbiblio reference audio pack.

| File | Duration | Semantic use | SHA-256 |
|---|---:|---|---|
| `soft_tap.wav` | 0.12 s | Saving a private record or reminder. | `01e3e8f4da61fb14906f5f3efbaf7c85e61caeb7929af6ddcfb8fc27cfe42223` |
| `gentle_completion.wav` | 0.55 s | Confirming one completed prayer action. | `33f32586f3501f6e200d03ef8f71575dd4810cde4fb18690e8065f822c997a21` |
| `publication_eligible.wav` | 0.82 s | The one-time transition to prayer publication eligibility. | `00978c4575448266a91e7c7fece01ecffba462322e6d9c9597ea2dcd2021b527` |

Generation format: mono PCM WAV, 22,050 Hz, signed 16-bit little-endian.
Regenerate from the repository root with:

```text
dart --packages=apps/soulbuddy/.dart_tool/package_config.json run tools/audio/generate_soulbuddy_tones.dart
```
