import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _sampleRate = 22050;

void main(List<String> arguments) {
  final output = arguments.isEmpty
      ? Directory('apps/soulbuddy/assets/audio/feedback')
      : Directory(arguments.single);
  output.createSync(recursive: true);

  final tones = <_ToneDefinition>[
    _ToneDefinition(
      filename: 'soft_tap.wav',
      durationSeconds: 0.12,
      use: 'Saving a private record or reminder.',
      sample: (time, progress) =>
          0.20 * math.sin(2 * math.pi * 660 * time) * _envelope(progress),
    ),
    _ToneDefinition(
      filename: 'gentle_completion.wav',
      durationSeconds: 0.55,
      use: 'Confirming one completed prayer action.',
      sample: (time, progress) {
        final first = math.sin(2 * math.pi * 523.25 * time);
        final second = math.sin(2 * math.pi * 659.25 * time);
        return 0.15 * (first + 0.55 * second) * _envelope(progress);
      },
    ),
    _ToneDefinition(
      filename: 'publication_eligible.wav',
      durationSeconds: 0.82,
      use: 'The one-time transition to prayer publication eligibility.',
      sample: (time, progress) {
        final frequency = progress < 0.34
            ? 523.25
            : progress < 0.67
            ? 659.25
            : 783.99;
        return 0.14 *
            (math.sin(2 * math.pi * frequency * time) +
                0.30 * math.sin(2 * math.pi * frequency * 2 * time)) *
            _envelope((progress * 3) % 1);
      },
    ),
  ];

  final manifestRows = <String>[];
  for (final tone in tones) {
    final bytes = _encodeWave(tone);
    final file = File('${output.path}/${tone.filename}');
    file.writeAsBytesSync(bytes, flush: true);
    manifestRows.add(
      '| `${tone.filename}` | ${tone.durationSeconds.toStringAsFixed(2)} s | '
      '${tone.use} | `${sha256.convert(bytes)}` |',
    );
  }

  File('${output.path}/ASSET-MANIFEST.md').writeAsStringSync('''
# SoulBuddy feedback tones

Generated specifically for SoulBuddy on 2026-08-12 by the deterministic
`tools/audio/generate_soulbuddy_tones.dart` script. These original synthesized
tones are dedicated under **CC0-1.0**. They do not contain or derive from the
Elbiblio reference audio pack.

| File | Duration | Semantic use | SHA-256 |
|---|---:|---|---|
${manifestRows.join('\n')}

Generation format: mono PCM WAV, 22,050 Hz, signed 16-bit little-endian.
Regenerate from the repository root with:

```text
dart --packages=apps/soulbuddy/.dart_tool/package_config.json run tools/audio/generate_soulbuddy_tones.dart
```
''');
}

double _envelope(double progress) {
  final attack = math.min(1.0, progress / 0.08);
  final release = math.pow(1 - progress.clamp(0, 1), 2).toDouble();
  return attack * release;
}

Uint8List _encodeWave(_ToneDefinition definition) {
  final sampleCount = (definition.durationSeconds * _sampleRate).round();
  final dataLength = sampleCount * 2;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, 36 + dataLength, Endian.little);
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, dataLength, Endian.little);

  for (var index = 0; index < sampleCount; index++) {
    final time = index / _sampleRate;
    final progress = index / sampleCount;
    final sample = definition.sample(time, progress).clamp(-1.0, 1.0);
    data.setInt16(44 + index * 2, (sample * 32767).round(), Endian.little);
  }
  return bytes;
}

class _ToneDefinition {
  const _ToneDefinition({
    required this.filename,
    required this.durationSeconds,
    required this.use,
    required this.sample,
  });

  final String filename;
  final double durationSeconds;
  final String use;
  final double Function(double time, double progress) sample;
}
