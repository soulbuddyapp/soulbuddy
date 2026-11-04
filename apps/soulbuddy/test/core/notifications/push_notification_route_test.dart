import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/notifications/push_registration.dart';

void main() {
  group('notice routes', () {
    test('opens the morning notice at Today', () {
      expect(notificationRoute({'kind': 'morning'}), '/today');
    });

    test('opens a weekly release notice at the release', () {
      expect(
        notificationRoute({
          'kind': 'weekly_prayer',
          'route': '/prayers/releases/renewed-mind-and-guarded-heart-v1',
        }),
        '/prayers/releases/renewed-mind-and-guarded-heart-v1',
      );
    });

    test('ignores a notice that opens nothing', () {
      expect(notificationRoute(null), isNull);
      expect(notificationRoute(<String, dynamic>{}), isNull);
      expect(notificationRoute({'kind': 'unknown_kind'}), isNull);
      expect(
        notificationRoute({'kind': 'morning', 'route': '/today'}),
        '/today',
      );
    });

    test('refuses a weekly route this app does not serve', () {
      // An unknown release shape must not strand someone on a blank screen.
      for (final route in const [
        '/prayers',
        '/prayers/releases',
        '/prayers/releases/',
        '/prayers/releases/a/b',
        '/today',
        '/prayers/saved/123',
        '/prayers/releases/x?y=1',
      ]) {
        expect(
          weeklyPrayerReleaseRoute(route),
          isNull,
          reason: '$route must not be offered as a release route',
        );
      }
    });

    test('refuses an absolute or foreign route', () {
      for (final route in const [
        'https://evil.example/prayers/releases/x',
        '//evil.example/prayers/releases/x',
      ]) {
        expect(weeklyPrayerReleaseRoute(route), isNull);
      }
    });

    test('drops a missing route rather than guessing', () {
      expect(notificationRoute({'kind': 'weekly_prayer'}), isNull);
      expect(notificationRoute({'kind': 'weekly_prayer', 'route': 42}), isNull);
    });
  });
}
