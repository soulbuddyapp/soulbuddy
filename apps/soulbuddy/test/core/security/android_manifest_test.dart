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

  test('no surface can start browser speech recognition', () {
    // The guard moved with the code it protected. `kIsWeb` now refuses inside
    // PluginSpeechRecognizer, before the plugin is reached at all, and
    // `plugin_speech_recognizer_test.dart` proves that behaviourally by
    // asserting no channel call is made. What a seam's own test cannot know is
    // who reaches for speech, so this asserts the guarantee cannot be read past:
    // a screen holding the plugin itself would never meet the guard, which is
    // why the check is on the importers rather than on one file's text.
    final importers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              file.readAsStringSync().contains('package:speech_to_text/'),
        )
        // Windows separators, so the expectation is the same path everywhere.
        .map((file) => file.path.replaceAll('\\', '/'))
        .toList();

    expect(importers, ['lib/core/speech/plugin_speech_recognizer.dart']);
  });
}
