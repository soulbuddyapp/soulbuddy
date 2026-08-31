# SoulBuddy Sacred Hour chimes

These four original tones were synthesized specifically for SoulBuddy by the
deterministic `tools/audio/generate_sacred_hour_chimes.dart` generator. They do
not contain, sample, or derive from the Elbiblio audio collection or any third-
party recording. SoulBuddy dedicates them under **CC0-1.0**.

Generator recipe: `sacred-hour-bells-v1`; mono PCM WAV, 44,100 Hz, signed 16-bit
little-endian. The synthesis uses softly attacked bell partials, independent
exponential decay, a restrained three-tap room tail, DC removal, a cosine end
fade, and conservative 0.72 peak normalization.

| File | Duration | Semantic use | Peak | RMS | SHA-256 |
|---|---:|---|---:|---:|---|
| `sacred_gentle_chime.wav` | 4.2 s | Default invitation into a Sacred Hour. | 0.720 | 0.153 | `a41b7ec7c1fcf32d569acf9e6557c8aaf96887279576274572f2053095d7d51c` |
| `sacred_dawn_chime.wav` | 4.8 s | A light upward invitation for the morning. | 0.720 | 0.121 | `284bccd006e3cf2316eb4201ad4ab16b3c022e1144003beb5b71e76b91dbf334` |
| `sacred_still_bell.wav` | 6.2 s | A spacious single bell for quiet attention. | 0.720 | 0.140 | `c90dca0e43cab9e1e00119e4ffb6890b90ec147076d83b4f452739f056de34fb` |
| `sacred_evening_chime.wav` | 5.4 s | A warm descending invitation for the evening. | 0.720 | 0.139 | `4ff1c482b92828fd5f3180cbe0a59bcffe15dd979c3132f52da1b597d05a41f9` |

The master, Android raw resource, and iOS bundle resource for each name must be
byte-identical. Regenerate all copies and this manifest from the repository root:

```text
dart --packages=apps/soulbuddy/.dart_tool/package_config.json run tools/audio/generate_sacred_hour_chimes.dart
```
