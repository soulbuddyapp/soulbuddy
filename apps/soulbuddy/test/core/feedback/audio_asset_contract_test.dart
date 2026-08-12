import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assetDirectory = 'assets/audio/feedback';
  const expectedFiles = {
    'soft_tap.wav',
    'gentle_completion.wav',
    'publication_eligible.wav',
  };
  const forbiddenElbiblioHashes = {
    '1785c4d2f011b4ebc9b917fa9043b5abc52a61784c358687ce2ff25537d27ade',
    '4645c4f92274855c6c93c3165a20c22f33220d6f7b44ed952ccf8e83d37fef69',
    '50a32171aed8e0bcccf318a8b60fab3cd41fea7c4e690c78da5683ef54881f01',
    '5e15958b0e600f41e5bc26e384b3106d59b8cac48d178c1a44fa493c18e591f6',
    'c6de97b747c21b28743ce460c5d02472cd725e57f5109a0211e77b388ae8b033',
    'c852652855da5f68f7412efeaa352190fc944f839d69633ab5b354d940ca5c24c',
    'ffddcc83edfaad9080d72a2742203f008d280ca0b159ee9b0337a74b6bd714e1',
  };

  test('ships only the three short original feedback tones', () async {
    final directory = Directory(assetDirectory);
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.wav'))
        .toList(growable: false);

    expect(
      files.map((file) => file.uri.pathSegments.last).toSet(),
      expectedFiles,
    );

    final hashes = <String>{};
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      hashes.add(hash);
      expect(bytes.length, lessThan(100000), reason: file.path);
      expect(_wavDuration(bytes), lessThanOrEqualTo(0.9), reason: file.path);
      expect(forbiddenElbiblioHashes, isNot(contains(hash)), reason: file.path);
    }
    expect(hashes, hasLength(expectedFiles.length));
  });

  test(
    'manifest records generation ownership, checksums, and semantic use',
    () async {
      final manifest = await File(
        '$assetDirectory/ASSET-MANIFEST.md',
      ).readAsString();

      expect(manifest, contains('Generated specifically for SoulBuddy'));
      expect(manifest, contains('CC0-1.0'));
      expect(manifest, contains('tools/audio/generate_soulbuddy_tones.dart'));
      for (final filename in expectedFiles) {
        final hash = sha256
            .convert(await File('$assetDirectory/$filename').readAsBytes())
            .toString();
        expect(manifest, contains('`$filename`'));
        expect(manifest.toLowerCase(), contains(hash));
      }
    },
  );
}

double _wavDuration(Uint8List bytes) {
  expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
  expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
  final data = ByteData.sublistView(bytes);
  final byteRate = data.getUint32(28, Endian.little);
  final dataLength = data.getUint32(40, Endian.little);
  return dataLength / byteRate;
}
