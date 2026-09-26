import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/application/commitment_session_clock.dart';

void main() {
  test('only foreground timer time counts, including repeated pauses', () {
    var now = Duration.zero;
    final clock = CommitmentSessionClock(
      planned: const Duration(minutes: 5),
      elapsed: () => now,
    );
    clock.start();
    now += const Duration(seconds: 43);
    clock.pause();
    now += const Duration(hours: 2);
    expect(clock.actual.inSeconds, 43);
    clock.start();
    now += const Duration(seconds: 17);
    clock.pause();
    expect(clock.actual.inSeconds, 60);
    expect(clock.completed, isFalse);
    clock.start();
    now += const Duration(minutes: 8);
    expect(clock.actual.inSeconds, 300);
    expect(clock.completed, isTrue);
    expect(clock.remaining, Duration.zero);
  });

  test('guide or a never-started session cannot claim meditation time', () {
    var now = Duration.zero;
    final clock = CommitmentSessionClock(
      planned: const Duration(minutes: 5),
      elapsed: () => now,
    );
    now += const Duration(minutes: 3);
    clock.pause();
    expect(clock.actual, Duration.zero);
    expect(clock.running, isFalse);
  });
}
