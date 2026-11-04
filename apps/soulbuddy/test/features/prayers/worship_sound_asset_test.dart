import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/worship_sound_bed.dart';

/// The bundled worship arrangements are real files, and the closing fade is
/// timed from each file's own length.
///
/// That length is written into the enum by hand, so this is what stops a
/// re-copy, a re-encode or a truncation from quietly turning the fade back into
/// a cut while every other test still passes. It also proves each bed's asset
/// resolves, since a path that does not exist on disk would never be heard.
void main() {
  const directory = 'assets/audio/worship';

  test('every bed ships the file it names, and every file is a bed', () {
    final present = Directory(directory)
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    final named = WorshipSoundBed.values
        .map((bed) => bed.assetPath.split('/').last)
        .toSet();

    expect(present, named, reason: 'a bed with no file, or a file with no bed');

    for (final bed in WorshipSoundBed.values) {
      final file = File('assets/${bed.assetPath}');
      expect(file.existsSync(), isTrue, reason: '${bed.assetPath} is missing');
      expect(file.lengthSync(), greaterThan(100000), reason: bed.assetPath);
    }
  });

  test('the directory is registered, so the files reach the app', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('$directory/'));
  });

  test('the fade is timed from each file, frame by frame', () {
    for (final bed in WorshipSoundBed.values) {
      final frames = _frameLength(
        File('assets/${bed.assetPath}').readAsBytesSync(),
      ).inMilliseconds;
      expect(
        bed.duration.inMilliseconds,
        frames,
        reason:
            '${bed.assetPath} holds $frames ms of audio. A shorter figure fades '
            'the music out mid-arrangement; a longer one puts the end of the '
            'fade past the end of the audio.',
      );
    }
  });

  test('each arrangement is a whole piece rather than a short loop', () {
    // The ambient beds are 60 to 108 seconds and repeat. An arrangement that
    // ends is never repeated, so a very short one would leave most of a
    // counted prayer with nothing playing at all.
    for (final bed in WorshipSoundBed.values) {
      expect(
        bed.duration,
        greaterThan(const Duration(minutes: 2)),
        reason: bed.label,
      );
    }
  });

  test('the files are pinned, so a re-export has to be a deliberate act', () {
    // If one of these changes, its length probably has too, and the fade is
    // timed from that length — so the change has to be made here as well.
    const sourceHashes = {
      '10000_reasons_instrumental.mp3':
          'f19ea59ce9b7fdef0188245f3b94732cdbda308203b0a2684f3d55f426119d0d',
      'anima_christi_instrumental.mp3':
          '00a9d5cc4ac81fef73d927fce277a2f123e25c6a4112b725215465fa1b10e8bb',
    };
    for (final bed in WorshipSoundBed.values) {
      final name = bed.assetPath.split('/').last;
      final hash = sha256
          .convert(File('assets/${bed.assetPath}').readAsBytesSync())
          .toString();
      expect(hash, sourceHashes[name], reason: name);
    }
  });
}

/// The length of every MP3 frame in the file, which is the length the player
/// reaches.
///
/// Frames are counted rather than the file size divided by a bitrate, because
/// one of these files begins with a tag whose declared length its own audio
/// runs straight through. The first frame is therefore found by looking for a
/// header that is followed by more headers, which is the only thing a header
/// inside that tag cannot fake.
Duration _frameLength(Uint8List bytes) {
  var offset = _firstFrame(bytes);
  var samples = 0;
  var sampleRate = 0;

  while (offset + 4 <= bytes.length) {
    final frame = _layerThreeFrame(bytes, offset);
    if (frame == null) break;
    sampleRate = frame.sampleRate;
    samples += frame.samples;
    offset += frame.length;
  }

  expect(sampleRate, greaterThan(0), reason: 'no MP3 frames were found');
  return Duration(
    microseconds: (samples * Duration.microsecondsPerSecond) ~/ sampleRate,
  );
}

int _firstFrame(Uint8List bytes) {
  for (var start = 0; start + 4 <= bytes.length; start++) {
    var probe = start;
    for (var chained = 0; chained < 8; chained++) {
      final frame = _layerThreeFrame(bytes, probe);
      if (frame == null) break;
      probe += frame.length;
      if (chained == 7) return start;
    }
  }
  throw const FormatException('the file holds no run of MP3 frames');
}

/// One Layer III frame header, or null where there is not one.
_Mp3Frame? _layerThreeFrame(Uint8List bytes, int offset) {
  if (bytes[offset] != 0xff || (bytes[offset + 1] & 0xe0) != 0xe0) {
    return null;
  }
  // version: 3 is MPEG1, 2 is MPEG2, 0 is MPEG2.5. layer 1 is Layer III.
  final version = (bytes[offset + 1] >> 3) & 0x03;
  if ((bytes[offset + 1] >> 1) & 0x03 != 1) return null;

  const kbps = [
    // MPEG1 Layer III, then MPEG2 and MPEG2.5 Layer III.
    [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
  ];
  const hertz = [
    [44100, 48000, 32000],
    [22050, 24000, 16000],
    [11025, 12000, 8000],
  ];

  final rate = (bytes[offset + 2] >> 4) & 0x0f;
  final pitch = (bytes[offset + 2] >> 2) & 0x03;
  // 0 and 15 are reserved, and so is a pitch of 3.
  if (rate == 0 || rate == 0x0f || pitch == 3) return null;

  final mpeg1 = version == 3;
  final sampleRate = hertz[mpeg1 ? 0 : (version == 2 ? 1 : 2)][pitch];
  final samples = mpeg1 ? 1152 : 576;
  final length =
      (samples ~/ 8 * kbps[mpeg1 ? 0 : 1][rate] * 1000 ~/ sampleRate) +
      (bytes[offset + 2] >> 1 & 0x01);
  if (length < 24 || offset + length > bytes.length) return null;

  return _Mp3Frame(length: length, samples: samples, sampleRate: sampleRate);
}

class _Mp3Frame {
  const _Mp3Frame({
    required this.length,
    required this.samples,
    required this.sampleRate,
  });

  final int length;
  final int samples;
  final int sampleRate;
}
