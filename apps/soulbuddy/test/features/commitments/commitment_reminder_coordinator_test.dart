import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/commitments/providers/commitment_providers.dart';
import 'package:soulbuddy/features/commitments/providers/commitment_reminder_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/commitments/application/commitment_reminder_coordinator.dart';
import 'package:soulbuddy/features/commitments/data/commitment_repository.dart';
import 'package:soulbuddy/features/commitments/data/commitment_reminder_device_repository.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'commitment_occurrence_calculator_test.dart' show testCommitmentPlan;

void main() {
  late _Repository repository;
  late _Devices devices;
  late _Scheduler scheduler;
  late CommitmentReminderCoordinator coordinator;
  setUp(() {
    repository = _Repository();
    devices = _Devices();
    scheduler = _Scheduler();
    coordinator = CommitmentReminderCoordinator(
      repository: repository,
      devices: devices,
      scheduler: scheduler,
      ownerId: 'owner',
      deviceId: 'device',
      clock: () => DateTime.utc(2026, 9, 24, 6),
      timezoneName: () async => 'Africa/Lagos',
    );
  });
  tearDown(() async {
    await coordinator.dispose();
    await scheduler.controller.close();
  });
  testWidgets(
    'provider reconciles on resume and detaches the observer on disposal',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          localIdentityProvider.overrideWith(
            (ref) async =>
                const LocalIdentity(ownerId: 'owner', deviceId: 'device'),
          ),
          commitmentRepositoryProvider.overrideWith((ref) async => repository),
          commitmentReminderDeviceRepositoryProvider.overrideWith(
            (ref) async => devices,
          ),
          prayerReminderSchedulerProvider.overrideWithValue(scheduler),
          prayerDeviceTimezoneProvider.overrideWithValue(
            () async => 'Africa/Lagos',
          ),
        ],
      );
      final active = await container.read(
        commitmentReminderCoordinatorProvider.future,
      );
      await active.enableOnThisDevice(
        'commitment',
        CommitmentReminderMode.silent,
      );
      await tester.pump();
      final before = scheduler.scheduled.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(scheduler.scheduled.length, greaterThan(before));
      container.dispose();
      await tester.pump();
      final disposed = scheduler.scheduled.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(scheduler.scheduled.length, disposed);
    },
  );
  test(
    'voice silent off modes replace only commitment notifications',
    () async {
      await coordinator.start();
      expect(scheduler.scheduled, isEmpty);
      expect(
        await coordinator.enableOnThisDevice(
          'commitment',
          CommitmentReminderMode.voice,
        ),
        isTrue,
      );
      expect(scheduler.scheduled.last.soundKey, 'commitment_invitation_v1');
      expect(
        scheduler.scheduled.last.recurrence,
        ReminderNotificationRecurrence.daily,
      );
      expect(scheduler.scheduled.last.platformNotificationId, isNegative);
      await coordinator.enableOnThisDevice(
        'commitment',
        CommitmentReminderMode.silent,
      );
      expect(scheduler.scheduled.last.soundKey, 'silent');
      await coordinator.enableOnThisDevice(
        'commitment',
        CommitmentReminderMode.off,
      );
      expect(devices.state!.notificationIds, isEmpty);
      expect(
        scheduler.cancelled.every((id) => (-id & 0xf8000000) == 0x30000000),
        isTrue,
      );
    },
  );
  test('denial preserves mode and plan without scheduling', () async {
    scheduler.allowed = false;
    await coordinator.start();
    expect(
      await coordinator.enableOnThisDevice(
        'commitment',
        CommitmentReminderMode.voice,
      ),
      isFalse,
    );
    expect(devices.state!.mode, CommitmentReminderMode.voice);
    expect(scheduler.scheduled, isEmpty);
    expect(repository.plan.enabled, isTrue);
  });
  test(
    'selected days recur weekly and survive reconciliation with stable ids',
    () async {
      repository.plan = testCommitmentPlan(
        frequency: CommitmentMeditationFrequency.selectedDays,
        mask: 5,
      );
      await coordinator.start();
      await coordinator.enableOnThisDevice(
        'commitment',
        CommitmentReminderMode.silent,
      );
      final ids = devices.state!.notificationIds;
      expect(ids, hasLength(2));
      expect(
        scheduler.scheduled.every(
          (n) => n.recurrence == ReminderNotificationRecurrence.weekly,
        ),
        isTrue,
      );
      await coordinator.refresh();
      expect(devices.state!.notificationIds, ids);
    },
  );
  test(
    'tap opens owned preparation only and ignores dismissed and foreign payloads',
    () async {
      await coordinator.start();
      final opened = <CommitmentReminderOpened>[];
      final sub = coordinator.events.listen(opened.add);
      for (final (id, action) in [
        ('foreign', PrayerReminderAction.open),
        ('commitment', PrayerReminderAction.dismiss),
        ('commitment', PrayerReminderAction.begin),
      ]) {
        scheduler.controller.add(
          PrayerReminderResponse(
            reminderId: id,
            occurrenceKey: 'day',
            action: action,
            kind: ReminderNotificationKind.commitment,
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      await coordinator.refresh();
      expect(opened.map((e) => e.commitmentId), ['commitment']);
      await sub.cancel();
    },
  );
  test(
    'missing voice scheduling falls back to silent without private errors',
    () async {
      scheduler.rejectVoice = true;
      await coordinator.start();
      await coordinator.enableOnThisDevice(
        'commitment',
        CommitmentReminderMode.voice,
      );
      expect(scheduler.scheduled.last.soundKey, 'silent');
    },
  );
}

class _Repository implements CommitmentRepository {
  CommitmentMeditationPlan plan = testCommitmentPlan();
  final commitment = Commitment(
    id: 'commitment',
    ownerId: 'owner',
    journeySlot: CommitmentJourneySlot.primary,
    goalId: 'goal',
    name: 'Private name',
    keyNeedOne: 'A',
    keyNeedTwo: 'B',
    keyNeedThree: 'C',
    calling: 'Private calling',
    guideId: CommitmentGuideId.peace,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  @override
  Stream<Commitment?> watchPrimary() => Stream.value(commitment);
  @override
  Stream<CommitmentDetails?> watchDetails(String id) => Stream.value(
    id == commitment.id
        ? CommitmentDetails(commitment: commitment, practices: [], plan: plan)
        : null,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Devices implements CommitmentReminderDeviceRepository {
  CommitmentReminderDeviceState? state;
  @override
  Future<CommitmentReminderDeviceState?> load(String id, String device) async =>
      state;
  @override
  Future<void> save(CommitmentReminderDeviceState value) async {
    state = value;
  }

  @override
  Future<void> clear(String id, String device) async {
    state = null;
  }
}

class _Scheduler implements PrayerReminderScheduler {
  final controller = StreamController<PrayerReminderResponse>.broadcast();
  final scheduled = <PrayerScheduledNotification>[];
  final cancelled = <int>[];
  bool allowed = true, rejectVoice = false;
  @override
  bool get supportsSystemNotifications => true;
  @override
  Stream<PrayerReminderResponse> get responses => controller.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<NotificationPermissionStatus> permissionStatus() async => allowed
      ? NotificationPermissionStatus.granted
      : NotificationPermissionStatus.denied;
  @override
  Future<void> schedule(PrayerScheduledNotification notification) async {
    if (rejectVoice && notification.soundKey != 'silent') {
      throw StateError('Private secret');
    }
    scheduled.add(notification);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> showTestReminder() async {}
}
