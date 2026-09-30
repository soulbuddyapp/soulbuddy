import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/notifications/local_reminder_recovery.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';

void main() {
  testWidgets(
    'permission granted by another service recovers without restart',
    (tester) async {
      var permission = NotificationPermissionStatus.denied;
      var recovered = 0;
      final recovery = LocalReminderRecovery(
        initialize: () async {},
        permissionStatus: () async => permission,
        recover: [
          () async {
            recovered++;
          },
        ],
        interval: const Duration(seconds: 1),
      );
      recovery.start();
      addTearDown(recovery.dispose);
      await tester.pump();
      expect(recovered, 1);
      permission = NotificationPermissionStatus.granted;
      await tester.pump(const Duration(seconds: 1));
      expect(recovered, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(recovered, 2);
      recovery.dispose();
    },
  );

  testWidgets('settings resume rearms alarms and polling stops in background', (
    tester,
  ) async {
    var permissionChecks = 0;
    var recovered = 0;
    final recovery = LocalReminderRecovery(
      initialize: () async {},
      permissionStatus: () async {
        permissionChecks++;
        return NotificationPermissionStatus.granted;
      },
      recover: [
        () async {
          recovered++;
        },
      ],
      interval: const Duration(seconds: 1),
    );
    recovery.start();
    addTearDown(recovery.dispose);
    await tester.pump();
    recovery.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(permissionChecks, 1);
    recovery.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(recovered, 2);
    recovery.dispose();
  });

  testWidgets(
    'transient initialization and coordinator failures recover on later ticks',
    (tester) async {
      var initializations = 0;
      var attempts = 0;
      var otherRecovered = 0;
      final recovery = LocalReminderRecovery(
        initialize: () async {
          if (initializations++ == 0) throw StateError('not ready');
        },
        permissionStatus: () async => NotificationPermissionStatus.granted,
        recover: [
          () async {
            if (attempts++ == 0) throw StateError('database not ready');
          },
          () async {
            otherRecovered++;
          },
        ],
        interval: const Duration(seconds: 1),
      );
      recovery.start();
      addTearDown(recovery.dispose);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 1);
      expect(otherRecovered, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 2);
      expect(otherRecovered, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 2);
      recovery.dispose();
    },
  );
}
