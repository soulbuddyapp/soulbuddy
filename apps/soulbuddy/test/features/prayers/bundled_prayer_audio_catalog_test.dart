import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/prayer_narration_playback_policy.dart';
import 'package:soulbuddy/features/prayers/application/bundled_prayer_audio.dart';

void main() {
  test('resolves only the exact prayer revision', () {
    final hash = sha256.convert(utf8.encode('A prayer')).toString();
    final catalog = BundledPrayerAudioCatalog.fromJson({
      'prayers': [
        {'id': 'p1', 'file': 'p1.mp3', 'body_sha256': hash},
      ],
    });
    expect(catalog.assetFor('p1', 'A prayer'), 'audio/prayers/p1.mp3');
    expect(catalog.assetFor('p1', 'Changed prayer'), isNull);
    expect(catalog.assetFor('other', 'A prayer'), isNull);
  });
  test('rejects duplicate ids and unsafe asset paths', () {
    expect(
      () => BundledPrayerAudioCatalog.fromJson({
        'prayers': [
          {'id': 'p', 'file': '../bad.mp3', 'body_sha256': 'x'},
        ],
      }),
      throwsFormatException,
    );
  });
  test(
    'an opened iPhone reminder may play while the player respects silent mode',
    () {
      expect(
        allowBundledReminderAutoplay(
          isIOS: true,
          route: PrayerAudioRoute.unknown,
          interruptionsAllowed: false,
        ),
        isTrue,
      );
      expect(
        allowBundledReminderAutoplay(
          isIOS: false,
          route: PrayerAudioRoute.doNotDisturb,
          interruptionsAllowed: false,
        ),
        isFalse,
      );
      expect(
        allowBundledReminderAutoplay(
          isIOS: false,
          route: PrayerAudioRoute.speaker,
          interruptionsAllowed: true,
        ),
        isTrue,
      );
    },
  );
}
