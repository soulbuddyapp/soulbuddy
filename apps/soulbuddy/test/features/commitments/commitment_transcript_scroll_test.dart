import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/application/commitment_audio.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_audio_reader.dart';

void main() {
  testWidgets('following a late phrase preserves the outer playback controls', (
    tester,
  ) async {
    final outer = ScrollController(), inner = ScrollController();
    final position = ValueNotifier(Duration.zero);
    final asset = CommitmentAudioAsset(
      id: 'guide',
      path: '',
      transcript: 'Prayer',
      duration: const Duration(seconds: 20),
      captions: List.generate(
        20,
        (i) => {
          'startMs': i * 1000,
          'endMs': (i + 1) * 1000,
          'text': 'A thoughtful prayer sentence $i.',
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: outer,
            child: Column(
              children: [
                const SizedBox(height: 60),
                TextButton(onPressed: () {}, child: const Text('Pause')),
                SizedBox(
                  height: 240,
                  child: SingleChildScrollView(
                    controller: inner,
                    child: ValueListenableBuilder(
                      valueListenable: position,
                      builder: (_, value, _) => CommitmentTranscript(
                        asset: asset,
                        position: value,
                        playing: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.getCenter(find.text('Pause'));
    position.value = const Duration(seconds: 18);
    await tester.pumpAndSettle();
    expect(inner.offset, greaterThan(0));
    expect(outer.offset, 0);
    expect(tester.getCenter(find.text('Pause')), button);
    await tester.pumpWidget(const SizedBox());
    outer.dispose();
    inner.dispose();
    position.dispose();
  });
}
