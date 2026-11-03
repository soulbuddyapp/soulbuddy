import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disables Android backup for encrypted secure storage', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('declares permissions for explicit voice input', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    final infoPlist = await File('ios/Runner/Info.plist').readAsString();

    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.RECORD_AUDIO" />',
      ),
    );
    expect(infoPlist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(
      infoPlist,
      contains(
        '<string>Record prayers and reflections with your microphone.</string>',
      ),
    );
    expect(manifest, contains('android.speech.RecognitionService'));
    expect(
      infoPlist,
      contains('<key>NSSpeechRecognitionUsageDescription</key>'),
    );
  });

  test('guided speech never starts browser speech recognition', () {
    final source = File(
      'lib/features/onboarding/presentation/first_prayer_speech_page.dart',
    ).readAsStringSync();

    expect(source, contains('if (kIsWeb)'));
    expect(
      source.indexOf('if (kIsWeb)'),
      lessThan(source.indexOf('_speech.initialize')),
    );
  });
}
