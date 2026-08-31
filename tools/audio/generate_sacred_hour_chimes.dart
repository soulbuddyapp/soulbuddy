import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _sampleRate = 44100;
const _generatorVersion = 'sacred-hour-bells-v1';

void main() {
  final repository = File.fromUri(Platform.script).parent.parent.parent;
  final masterDirectory = Directory(
    '${repository.path}/apps/soulbuddy/assets/audio/sacred_hours',
  )..createSync(recursive: true);
  final androidDirectory = Directory(
    '${repository.path}/apps/soulbuddy/android/app/src/main/res/raw',
  )..createSync(recursive: true);
  final iosDirectory = Directory(
    '${repository.path}/apps/soulbuddy/ios/Runner/Sounds',
  )..createSync(recursive: true);

  final definitions = <_ChimeDefinition>[
    const _ChimeDefinition(
      filename: 'sacred_gentle_chime.wav',
      semanticUse: 'Default invitation into a Sacred Hour.',
      durationSeconds: 4.2,
      strikes: [
        _Strike(time: 0.08, frequency: 523.25, gain: 0.78, decay: 1.55),
        _Strike(time: 0.62, frequency: 659.25, gain: 0.56, decay: 1.75),
      ],
      roomMix: 0.12,
    ),
    const _ChimeDefinition(
      filename: 'sacred_dawn_chime.wav',
      semanticUse: 'A light upward invitation for the morning.',
      durationSeconds: 4.8,
      strikes: [
        _Strike(time: 0.08, frequency: 392.00, gain: 0.58, decay: 1.45),
        _Strike(time: 0.42, frequency: 523.25, gain: 0.68, decay: 1.62),
        _Strike(time: 0.78, frequency: 659.25, gain: 0.54, decay: 1.82),
      ],
      roomMix: 0.10,
    ),
    const _ChimeDefinition(
      filename: 'sacred_still_bell.wav',
      semanticUse: 'A spacious single bell for quiet attention.',
      durationSeconds: 6.2,
      strikes: [
        _Strike(time: 0.10, frequency: 293.66, gain: 0.82, decay: 2.55),
        _Strike(time: 0.13, frequency: 440.00, gain: 0.20, decay: 2.10),
      ],
      roomMix: 0.16,
    ),
    const _ChimeDefinition(
      filename: 'sacred_evening_chime.wav',
      semanticUse: 'A warm descending invitation for the evening.',
      durationSeconds: 5.4,
      strikes: [
        _Strike(time: 0.08, frequency: 659.25, gain: 0.48, decay: 1.65),
        _Strike(time: 0.52, frequency: 523.25, gain: 0.64, decay: 1.88),
        _Strike(time: 0.96, frequency: 392.00, gain: 0.66, decay: 2.20),
      ],
      roomMix: 0.14,
    ),
  ];

  final rendered = <_RenderedChime>[];
  for (final definition in definitions) {
    final samples = _synthesize(definition);
    final bytes = _encodeWave(samples);
    final master = File('${masterDirectory.path}/${definition.filename}')
      ..writeAsBytesSync(bytes, flush: true);
    File('${androidDirectory.path}/${definition.filename}')
      ..writeAsBytesSync(bytes, flush: true);
    File('${iosDirectory.path}/${definition.filename}')
      ..writeAsBytesSync(bytes, flush: true);
    rendered.add(
      _RenderedChime(
        definition: definition,
        hash: sha256.convert(bytes).toString(),
        peak: samples.map((sample) => sample.abs()).reduce(math.max),
        rms: math.sqrt(
          samples.fold<double>(0, (sum, sample) => sum + sample * sample) /
              samples.length,
        ),
      ),
    );
    stdout.writeln('Rendered ${master.path}');
  }

  File(
    '${masterDirectory.path}/ASSET-MANIFEST.md',
  ).writeAsStringSync(_manifest(rendered), flush: true);
}

List<double> _synthesize(_ChimeDefinition definition) {
  final length = (definition.durationSeconds * _sampleRate).round();
  final dry = List<double>.filled(length, 0);
  const partials = <(double, double, double)>[
    (1.000, 1.00, 1.00),
    (2.012, 0.32, 0.68),
    (2.985, 0.15, 0.48),
    (4.080, 0.065, 0.34),
    (5.430, 0.028, 0.24),
  ];
  for (final strike in definition.strikes) {
    final start = (strike.time * _sampleRate).round();
    for (var index = start; index < length; index++) {
      final elapsed = (index - start) / _sampleRate;
      final attack = 1 - math.exp(-elapsed / 0.014);
      var value = 0.0;
      for (final (ratio, amplitude, decayScale) in partials) {
        final phase = 2 * math.pi * strike.frequency * ratio * elapsed;
        final decay = math.exp(-elapsed / (strike.decay * decayScale));
        value += math.sin(phase) * amplitude * decay;
      }
      dry[index] += value * attack * strike.gain;
    }
  }

  final wet = List<double>.from(dry);
  for (final (milliseconds, gain) in const <(int, double)>[
    (83, 0.58),
    (149, 0.34),
    (233, 0.20),
  ]) {
    final delay = (_sampleRate * milliseconds / 1000).round();
    for (var index = delay; index < length; index++) {
      wet[index] += dry[index - delay] * definition.roomMix * gain;
    }
  }

  final mean = wet.reduce((left, right) => left + right) / wet.length;
  for (var index = 0; index < wet.length; index++) {
    wet[index] -= mean;
  }
  final fadeSamples = (_sampleRate * 0.45).round();
  for (var offset = 0; offset < fadeSamples; offset++) {
    final index = wet.length - fadeSamples + offset;
    final envelope = 0.5 * (1 + math.cos(math.pi * offset / fadeSamples));
    wet[index] *= envelope;
  }
  final peak = wet.map((sample) => sample.abs()).reduce(math.max);
  final scale = 0.72 / peak;
  for (var index = 0; index < wet.length; index++) {
    wet[index] *= scale;
  }
  return wet;
}

Uint8List _encodeWave(List<double> samples) {
  const channels = 1;
  const bitsPerSample = 16;
  const bytesPerSample = bitsPerSample ~/ 8;
  final dataSize = samples.length * bytesPerSample;
  final output = ByteData(44 + dataSize);
  void asciiAt(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      output.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  asciiAt(0, 'RIFF');
  output.setUint32(4, 36 + dataSize, Endian.little);
  asciiAt(8, 'WAVE');
  asciiAt(12, 'fmt ');
  output.setUint32(16, 16, Endian.little);
  output.setUint16(20, 1, Endian.little);
  output.setUint16(22, channels, Endian.little);
  output.setUint32(24, _sampleRate, Endian.little);
  output.setUint32(28, _sampleRate * channels * bytesPerSample, Endian.little);
  output.setUint16(32, channels * bytesPerSample, Endian.little);
  output.setUint16(34, bitsPerSample, Endian.little);
  asciiAt(36, 'data');
  output.setUint32(40, dataSize, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    final integer = (samples[index].clamp(-1.0, 1.0) * 32767).round();
    output.setInt16(44 + index * 2, integer, Endian.little);
  }
  return output.buffer.asUint8List();
}

String _manifest(List<_RenderedChime> tones) {
  final rows = tones
      .map((tone) {
        final definition = tone.definition;
        return '| `${definition.filename}` | '
            '${definition.durationSeconds.toStringAsFixed(1)} s | '
            '${definition.semanticUse} | '
            '${tone.peak.toStringAsFixed(3)} | '
            '${tone.rms.toStringAsFixed(3)} | `${tone.hash}` |';
      })
      .join('\n');
  return '''# SoulBuddy Sacred Hour chimes

These four original tones were synthesized specifically for SoulBuddy by the
deterministic `tools/audio/generate_sacred_hour_chimes.dart` generator. They do
not contain, sample, or derive from the Elbiblio audio collection or any third-
party recording. SoulBuddy dedicates them under **CC0-1.0**.

Generator recipe: `$_generatorVersion`; mono PCM WAV, 44,100 Hz, signed 16-bit
little-endian. The synthesis uses softly attacked bell partials, independent
exponential decay, a restrained three-tap room tail, DC removal, a cosine end
fade, and conservative 0.72 peak normalization.

| File | Duration | Semantic use | Peak | RMS | SHA-256 |
|---|---:|---|---:|---:|---|
$rows

The master, Android raw resource, and iOS bundle resource for each name must be
byte-identical. Regenerate all copies and this manifest from the repository root:

```text
dart --packages=apps/soulbuddy/.dart_tool/package_config.json run tools/audio/generate_sacred_hour_chimes.dart
```
''';
}

class _ChimeDefinition {
  const _ChimeDefinition({
    required this.filename,
    required this.semanticUse,
    required this.durationSeconds,
    required this.strikes,
    required this.roomMix,
  });

  final String filename;
  final String semanticUse;
  final double durationSeconds;
  final List<_Strike> strikes;
  final double roomMix;
}

class _Strike {
  const _Strike({
    required this.time,
    required this.frequency,
    required this.gain,
    required this.decay,
  });

  final double time;
  final double frequency;
  final double gain;
  final double decay;
}

class _RenderedChime {
  const _RenderedChime({
    required this.definition,
    required this.hash,
    required this.peak,
    required this.rms,
  });

  final _ChimeDefinition definition;
  final String hash;
  final double peak;
  final double rms;
}
