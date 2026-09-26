import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/native_prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';

void main() {
  test(
    'release resource shrinking preserves the dynamically selected voice',
    () {
      expect(
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
        contains('@raw/commitment_invitation_v1'),
      );
    },
  );
  test(
    'commitment voice notification has generic text and never starts session audio',
    () async {
      final client = _Client();
      final scheduler = NativePrayerReminderScheduler(client: client);
      await scheduler.schedule(
        PrayerScheduledNotification(
          platformNotificationId: -1,
          reminderId: 'commitment',
          occurrenceKey: 'day',
          scheduledAtUtc: DateTime.utc(2026),
          kind: ReminderNotificationKind.commitment,
          soundKey: 'commitment_invitation_v1',
        ),
      );
      final request = client.request!;
      expect(request.title, 'Time with God');
      expect(request.startsAudio, isFalse);
      expect(request.soundKey, 'commitment_invitation_v1');
      expect(request.actions.map((a) => a.id), ['BEGIN', 'DISMISS']);
    },
  );
}

class _Client implements NativePrayerNotificationClient {
  NativeNotificationRequest? request;
  @override
  Future<void> schedule(NativeNotificationRequest request) async {
    this.request = request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
