import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/presentation/bundled_prayer_audio_button.dart';

class FakeVoice implements BundledPrayerVoice {
  @override
  Stream<void> get completions => const Stream.empty();
  var played = 0;
  var stopped = 0;
  @override
  Future<void> play(String asset) async {
    played++;
  }

  @override
  Future<void> stop() async {
    stopped++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('plays and stops a prepared prayer', (tester) async {
    final voice = FakeVoice();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BundledPrayerAudioButton(
            asset: 'audio/prayers/a.mp3',
            voice: voice,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Play prayer'));
    await tester.pump();
    expect(voice.played, 1);
    await tester.tap(find.text('Stop prayer'));
    await tester.pump();
    expect(voice.stopped, 1);
  });
  testWidgets('starts automatically when the caller requests it', (
    tester,
  ) async {
    final voice = FakeVoice();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BundledPrayerAudioButton(
            asset: 'audio/prayers/a.mp3',
            voice: voice,
            autoplay: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(voice.played, 1);
    expect(find.text('Stop prayer'), findsOneWidget);
  });
}
