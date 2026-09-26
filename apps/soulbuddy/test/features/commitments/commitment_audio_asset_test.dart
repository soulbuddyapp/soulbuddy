import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog =
      jsonDecode(
            File('assets/audio/commitments/catalog_v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final assets = (catalog['assets'] as List).cast<Map<String, dynamic>>();

  test('ships complete narration, captions, music and provenance', () {
    expect(catalog['schemaVersion'], 1);
    expect(catalog['defaultPlaybackRate'], 0.85);
    expect(catalog['captionTimebase'], 'sourceMediaMilliseconds');
    expect(assets.map((a) => a['id']).toSet(), {
      'readiness_v1',
      'invitation_v1',
      'guide_surrender_v1',
      'guide_direction_v1',
      'guide_peace_v1',
      'listening_v1',
      'spoken_invitation_v1',
      'aphelion_excerpt_v1',
    });
    final manifest = File(
      'assets/audio/commitments/ASSET-MANIFEST.md',
    ).readAsStringSync();
    for (final asset in assets) {
      final bytes = File(asset['path'] as String).readAsBytesSync();
      expect(sha256.convert(bytes).toString(), asset['sha256']);
      expect(manifest, contains(asset['sha256']));
      expect(asset['required'], false);
      expect(asset['provenance']['privateContent'], false);
      if (asset['id'] == 'aphelion_excerpt_v1') continue;
      final transcript = File(asset['transcriptPath'] as String);
      expect(transcript.readAsStringSync().trim(), asset['transcript']);
      expect(
        sha256.convert(transcript.readAsBytesSync()).toString(),
        asset['transcriptSha256'],
      );
      final captions = (asset['captions'] as List).cast<Map<String, dynamic>>();
      expect(captions, isNotEmpty);
      var previousEnd = 0;
      for (final caption in captions) {
        expect(caption['startMs'], greaterThanOrEqualTo(previousEnd));
        expect(caption['endMs'], greaterThan(caption['startMs'] as int));
        expect(caption['endMs'], lessThanOrEqualTo(asset['durationMs'] as int));
        previousEnd = caption['endMs'] as int;
      }
    }
  });

  test('music retains exact approved source interval and attribution', () {
    final music = assets.singleWhere((a) => a['id'] == 'aphelion_excerpt_v1');
    expect(music['provenance']['sourceIntervalSeconds'], [105, 135]);
    expect(music['durationMs'], inInclusiveRange(29950, 30100));
    expect(music['license']['identifier'], 'CC-BY-4.0');
    expect(
      music['license']['attribution'],
      '“Aphelion” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au',
    );
  });

  test('notification masters are byte-identical and bundled on mobile', () {
    final spoken = assets.singleWhere((a) => a['id'] == 'spoken_invitation_v1');
    expect(spoken['durationMs'], lessThan(30000));
    for (final path in spoken['platformCopies'] as List) {
      expect(
        sha256.convert(File('../../$path').readAsBytesSync()).toString(),
        spoken['sha256'],
      );
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/audio/commitments/'),
    );
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(project, contains('commitment_invitation_v1.wav in Resources'));
    expect(project, contains('path = Sounds/commitment_invitation_v1.wav'));
  });
}
