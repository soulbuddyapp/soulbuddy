import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/async/retryable_future_cache.dart';

void main() {
  test('shares a successful future', () async {
    final cache = RetryableFutureCache<int>();
    var opens = 0;

    expect(await cache.get(() async => ++opens), 1);
    expect(await cache.get(() async => ++opens), 1);
    expect(opens, 1);
  });

  test('opens again after a failed future', () async {
    final cache = RetryableFutureCache<int>();
    var opens = 0;

    await expectLater(
      cache.get(() async {
        opens++;
        throw StateError('first load failed');
      }),
      throwsStateError,
    );

    expect(await cache.get(() async => ++opens), 2);
  });
}
