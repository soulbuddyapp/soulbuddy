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
    expect(manifest, contains('android.speech.RecognitionService'));
    expect(
      infoPlist,
      contains('<key>NSSpeechRecognitionUsageDescription</key>'),
    );

    // Apple shows these verbatim in the permission prompt, so each is asserted
    // against its own key rather than merely present somewhere in the file. The
    // copy states the guarantee that matters, not which screens speak: the old
    // wording named prayer details alone, and speech is now offered at many
    // surfaces.
    const consent =
        'SoulBuddy uses the microphone only when you choose to speak, and never '
        'sends your voice anywhere.';
    for (final key in const [
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
    ]) {
      expect(
        // The plist is read as bytes, so its CRLF endings are part of the text
        // a match has to allow for.
        RegExp(
          '<key>$key</key>\\s*<string>${RegExp.escape(consent)}</string>',
        ).hasMatch(infoPlist),
        isTrue,
        reason: 'the prompt for $key must carry this exact sentence',
      );
    }
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
