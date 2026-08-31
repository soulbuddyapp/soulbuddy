import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const filenames = [
    'sacred_gentle_chime.wav',
    'sacred_dawn_chime.wav',
    'sacred_still_bell.wav',
    'sacred_evening_chime.wav',
  ];
  const knownElbiblioHashes = {
    'c441f032b8268dcfa4427f24cb88bf0b165b5aeca9d35dfb1bc301731fe583a9',
    'c6de97b747c21b28743ce460c5d02472cd725e57f5109a0211e77b388ae8b033',
    '1785c4d2f011b4ebc9b917fa9043b5abc52a61784c358687ce2ff25537d27ade',
    'c852652855daf68f7412efeaa352190fc944f839d69633ab5b354d940ca5c24c',
    '1b65fb4aaced38d602b80421b86903fa08a562083139534c660fa3b0d6d74331',
  };

  test('ships four original, safe, byte-identical Sacred Hour chimes', () {
    final manifest = File(
      'assets/audio/sacred_hours/ASSET-MANIFEST.md',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final iosProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final hashes = <String>{};

    expect(manifest, contains('CC0-1.0'));
    expect(manifest, contains('generate_sacred_hour_chimes.dart'));
    expect(pubspec, contains('assets/audio/sacred_hours/'));

    for (final filename in filenames) {
      final master = File('assets/audio/sacred_hours/$filename');
      final android = File('android/app/src/main/res/raw/$filename');
      final ios = File('ios/Runner/Sounds/$filename');
      expect(
        master.existsSync(),
        isTrue,
        reason: '$filename master is missing',
      );
      expect(
        android.existsSync(),
        isTrue,
        reason: '$filename Android copy is missing',
      );
      expect(ios.existsSync(), isTrue, reason: '$filename iOS copy is missing');

      final bytes = master.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      hashes.add(hash);
      expect(sha256.convert(android.readAsBytesSync()).toString(), hash);
      expect(sha256.convert(ios.readAsBytesSync()).toString(), hash);
      expect(knownElbiblioHashes, isNot(contains(hash)));
      expect(manifest, contains(filename));
      expect(manifest, contains(hash));
      expect(iosProject, contains(filename));

      final wave = _readWave(bytes);
      expect(wave.sampleRate, 44100);
      expect(wave.channels, 1);
      expect(wave.bitsPerSample, 16);
      expect(wave.durationSeconds, inInclusiveRange(2.0, 8.0));
      expect(wave.peak, lessThan(0.95));
      expect(wave.rms, inInclusiveRange(0.005, 0.25));
    }

    expect(hashes, hasLength(filenames.length));
  });
}

_WaveStats _readWave(List<int> source) {
  final bytes = Uint8List.fromList(source);
  final data = ByteData.sublistView(bytes);
  expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
  expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
  expect(ascii.decode(bytes.sublist(12, 16)), 'fmt ');
  final channels = data.getUint16(22, Endian.little);
  final sampleRate = data.getUint32(24, Endian.little);
  final bitsPerSample = data.getUint16(34, Endian.little);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = ascii.decode(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      final sampleCount = size ~/ 2;
      var peak = 0.0;
      var energy = 0.0;
      for (var index = 0; index < sampleCount; index++) {
        final sample =
            data.getInt16(offset + 8 + index * 2, Endian.little) / 32768;
        peak = math.max(peak, sample.abs());
        energy += sample * sample;
      }
      return _WaveStats(
        channels: channels,
        sampleRate: sampleRate,
        bitsPerSample: bitsPerSample,
        durationSeconds: sampleCount / sampleRate / channels,
        peak: peak,
        rms: math.sqrt(energy / sampleCount),
      );
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV data chunk is missing');
}

class _WaveStats {
  const _WaveStats({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.durationSeconds,
    required this.peak,
    required this.rms,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final double durationSeconds;
  final double peak;
  final double rms;
}
