import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every bundled prayer has matching, nonempty offline narration', () {
    final catalog =
        jsonDecode(
              File('assets/content/prayer_library.json').readAsStringSync(),
            )
            as Map;
    final manifest =
        jsonDecode(
              File('assets/audio/prayers/manifest.json').readAsStringSync(),
            )
            as Map;
    final entries = (manifest['prayers'] as List).cast<Map>();
    final prayers = (catalog['prayers'] as List).cast<Map>();
    expect(entries.length, prayers.length);
    expect(entries.map((e) => e['id']).toSet().length, entries.length);
    for (final prayer in prayers) {
      final entry = entries.singleWhere((e) => e['id'] == prayer['id']);
      expect(
        entry['body_sha256'],
        sha256.convert(utf8.encode(prayer['body'] as String)).toString(),
      );
      final file = File('assets/audio/prayers/${entry['file']}');
      expect(
        file.existsSync(),
        isTrue,
        reason: '${prayer['id']} missing audio',
      );
      expect(file.lengthSync(), greaterThan(1000));
      final index = int.parse(
        (prayer['id'] as String).substring((prayer['id'] as String).length - 1),
      );
      final platform = File(
        'android/app/src/main/res/raw/builtin_prayer_0$index.mp3',
      );
      expect(platform.existsSync(), isTrue);
      expect(
        sha256.convert(platform.readAsBytesSync()),
        sha256.convert(file.readAsBytesSync()),
      );
      if (index < 9)
        expect(
          File('ios/Runner/Sounds/builtin_prayer_0$index.wav').lengthSync(),
          greaterThan(1000),
        );
    }
  });
}
