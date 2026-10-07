import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/prayer_narration_eligibility.dart';
import 'package:soulbuddy/features/prayers/application/prayer_narration_player.dart';
import 'package:soulbuddy/features/prayers/data/prayer_narration_repository.dart';
import 'package:soulbuddy/features/prayers/data/prayer_practice_repository.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_narration.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_session.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';

void main() {
  test('narration is obtainable for an ordinary personal prayer revision', () {
    expect(
      canObtainPrayerNarration(
        personalPrayerId: 'prayer-1',
        prayerRevisionId: 'revision-1',
        prayerBody: 'Father, hold this life close.',
      ),
      isTrue,
    );
  });

  test(
    'narration is unobtainable once the prayer is longer than the limit',
    () {
      expect(
        canObtainPrayerNarration(
          personalPrayerId: 'prayer-1',
          prayerRevisionId: 'revision-1',
          prayerBody: 'a' * prayerNarrationMaximumCharacters,
        ),
        isTrue,
      );
      expect(
        canObtainPrayerNarration(
          personalPrayerId: 'prayer-1',
          prayerRevisionId: 'revision-1',
          prayerBody: 'a' * (prayerNarrationMaximumCharacters + 1),
        ),
        isFalse,
      );
    },
  );

  test('narration is unobtainable without a saved revision or any text', () {
    expect(
      canObtainPrayerNarration(
        personalPrayerId: 'prayer-1',
        prayerRevisionId: '',
        prayerBody: 'Father.',
      ),
      isFalse,
    );
    expect(
      canObtainPrayerNarration(
        personalPrayerId: '',
        prayerRevisionId: 'revision-1',
        prayerBody: 'Father.',
      ),
      isFalse,
    );
    expect(
      canObtainPrayerNarration(
        personalPrayerId: 'prayer-1',
        prayerRevisionId: 'revision-1',
        prayerBody: '   ',
      ),
      isFalse,
    );
  });

  test(
    'requests, caches privately and plays an uncached personal prayer',
    () async {
      final requests =
          <({String personalPrayerId, String revisionId, bool consent})>[];
      final repository = _RecordingRepository();
      final played = <Uint8List>[];
      final container = ProviderContainer(
        overrides: [
          preparePersonalPrayerNarrationProvider.overrideWithValue(({
            required personalPrayerId,
            required revisionId,
            required consent,
          }) async {
            requests.add((
              personalPrayerId: personalPrayerId,
              revisionId: revisionId,
              consent: consent,
            ));
            return PrayerNarration(
              revisionId: revisionId,
              contentType: 'audio/mpeg',
              bytes: Uint8List.fromList([7, 8, 9]),
            );
          }),
          prayerPracticeRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          prayerNarrationPlayerProvider.overrideWithValue(
            _RecordingPlayer(played),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(prepareAndPlayReminderNarrationProvider)(
        _occurrence(),
        consentAccepted: true,
      );

      // Only the exact immutable revision is sent, and only after consent.
      expect(requests, [
        (personalPrayerId: 'prayer-1', revisionId: 'revision-1', consent: true),
      ]);
      // The audio is cached privately on this device and never opts into
      // autoplay, which stays a separate, explicit choice.
      expect(repository.reminderIds, ['reminder-1']);
      expect(repository.revisionIds, ['revision-1']);
      expect(repository.consentAccepted, [true]);
      expect(repository.autoplayWhenOpened, [false]);
      expect(repository.byteCounts, [3]);
      expect(repository.contentTypes, ['audio/mpeg']);
      expect(played, [
        Uint8List.fromList([7, 8, 9]),
      ]);
    },
  );

  test('one tap requests once, and a later tap uses the cache', () async {
    var requests = 0;
    final played = <Uint8List>[];
    final repository = _RecordingRepository();
    final container = ProviderContainer(
      overrides: [
        preparePersonalPrayerNarrationProvider.overrideWithValue(({
          required personalPrayerId,
          required revisionId,
          required consent,
        }) async {
          requests++;
          return PrayerNarration(
            revisionId: revisionId,
            contentType: 'audio/mpeg',
            bytes: Uint8List.fromList([1, 2, 3]),
          );
        }),
        prayerPracticeRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        prayerNarrationPlayerProvider.overrideWithValue(
          _RecordingPlayer(played),
        ),
      ],
    );
    addTearDown(container.dispose);

    final play = container.read(prepareAndPlayReminderNarrationProvider);
    // Two taps before the first request settles must not request twice.
    await Future.wait([
      play(_occurrence(), consentAccepted: true),
      play(_occurrence(), consentAccepted: true),
    ]);
    expect(requests, 1);

    // Once the device row holds that exact revision, nothing is asked for again.
    await play(_occurrence(cached: true), consentAccepted: false);
    expect(requests, 1);
    expect(played, [
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([1, 2, 3]),
    ]);
  });

  test('never requests narration without accepted consent', () async {
    var requests = 0;
    final container = ProviderContainer(
      overrides: [
        preparePersonalPrayerNarrationProvider.overrideWithValue(({
          required personalPrayerId,
          required revisionId,
          required consent,
        }) async {
          requests++;
          return PrayerNarration(
            revisionId: revisionId,
            contentType: 'audio/mpeg',
            bytes: Uint8List.fromList([1]),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(prepareAndPlayReminderNarrationProvider)(
        _occurrence(),
        consentAccepted: false,
      ),
      throwsA(
        isA<PrayerNarrationException>().having(
          (error) => error.code,
          'code',
          'consent_required',
        ),
      ),
    );
    expect(requests, 0);
  });

  test('never requests narration the server would refuse', () async {
    var requests = 0;
    final container = ProviderContainer(
      overrides: [
        preparePersonalPrayerNarrationProvider.overrideWithValue(({
          required personalPrayerId,
          required revisionId,
          required consent,
        }) async {
          requests++;
          return PrayerNarration(
            revisionId: revisionId,
            contentType: 'audio/mpeg',
            bytes: Uint8List.fromList([1]),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(prepareAndPlayReminderNarrationProvider)(
        _occurrence(body: 'a' * (prayerNarrationMaximumCharacters + 1)),
        consentAccepted: true,
      ),
      throwsA(
        isA<PrayerNarrationException>().having(
          (error) => error.code,
          'code',
          'narration_unavailable',
        ),
      ),
    );
    expect(requests, 0);
  });

  test('a rejected narration is never cached and can be retried', () async {
    var requests = 0;
    final repository = _RecordingRepository();
    final container = ProviderContainer(
      overrides: [
        preparePersonalPrayerNarrationProvider.overrideWithValue(({
          required personalPrayerId,
          required revisionId,
          required consent,
        }) async {
          requests++;
          throw const PrayerNarrationException('narration_unavailable');
        }),
        prayerPracticeRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        prayerNarrationPlayerProvider.overrideWithValue(
          _RecordingPlayer(<Uint8List>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final play = container.read(prepareAndPlayReminderNarrationProvider);
    await expectLater(
      play(_occurrence(), consentAccepted: true),
      throwsA(isA<PrayerNarrationException>()),
    );
    expect(repository.revisionIds, isEmpty);

    await expectLater(
      play(_occurrence(), consentAccepted: true),
      throwsA(isA<PrayerNarrationException>()),
    );
    // The failed attempt released its slot, so a retry is possible.
    expect(requests, 2);
    expect(repository.revisionIds, isEmpty);
  });
}

DuePrayerOccurrence _occurrence({String? body, bool cached = false}) {
  final at = DateTime.utc(2026, 8, 11, 18);
  return DuePrayerOccurrence(
    reminder: PrayerReminder(
      id: 'reminder-1',
      ownerId: 'owner-1',
      personalPrayerId: 'prayer-1',
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 19, minute: 0),
        timezone: 'Africa/Lagos',
      ),
      enabled: true,
      createdAt: at,
      updatedAt: at,
    ),
    device: PrayerReminderDevice(
      id: 'device-row-1',
      reminderId: 'reminder-1',
      deviceId: 'device-1',
      enabledOnDevice: true,
      nextOccurrenceAt: at,
      platformNotificationId: 77,
      scheduledTimezone: 'Africa/Lagos',
      updatedAt: at,
      narrationRevisionId: cached ? 'revision-1' : null,
      narrationBytes: cached ? const [1, 2, 3] : null,
      narrationContentType: cached ? 'audio/mpeg' : null,
    ),
    prayerTitle: 'Evening prayer',
    prayerBody: body ?? 'Father, hold this life close.',
    prayerRevisionId: 'revision-1',
    occurrenceAt: at,
  );
}

class _RecordingPlayer implements PrayerNarrationPlayer {
  _RecordingPlayer(this.played);
  final List<Uint8List> played;

  @override
  Future<void> play(Uint8List bytes) async => played.add(bytes);
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> close() async {}
}

class _RecordingRepository implements PrayerPracticeRepository {
  final consentAccepted = <bool>[];
  final autoplayWhenOpened = <bool>[];
  final reminderIds = <String>[];
  final revisionIds = <String?>[];
  final byteCounts = <int>[];
  final contentTypes = <String?>[];

  @override
  Future<void> saveNarrationPreference({
    required String reminderId,
    required bool consentAccepted,
    required bool autoplayWhenOpened,
    String? revisionId,
    List<int>? bytes,
    String? contentType,
  }) async {
    this.consentAccepted.add(consentAccepted);
    this.autoplayWhenOpened.add(autoplayWhenOpened);
    reminderIds.add(reminderId);
    revisionIds.add(revisionId);
    byteCounts.add(bytes?.length ?? 0);
    contentTypes.add(contentType);
  }

  @override
  Stream<PrayerReminder?> watchReminder(String personalPrayerId) =>
      const Stream.empty();
  @override
  Stream<PrayerReminderDevice?> watchDevice(String reminderId) =>
      const Stream.empty();
  @override
  Stream<List<DuePrayerOccurrence>> watchDue(DateTime atUtc) =>
      const Stream.empty();
  @override
  Stream<int> watchSessionCount(String revisionId) => const Stream.empty();
  @override
  Stream<bool> watchSessionForDate(
    PrayerReference prayer,
    DateTime localDate, {
    String? revisionId,
  }) => const Stream.empty();
  @override
  Future<int> getSessionCount(String revisionId) async => 0;
  @override
  Future<PrayerReminder> saveReminder({
    required String personalPrayerId,
    required PrayerReminderSchedule schedule,
    required bool enableOnThisDevice,
  }) => throw UnimplementedError();
  @override
  Future<void> archiveReminder(String reminderId) async {}
  @override
  Future<void> setDeviceEnabled(
    String reminderId, {
    required bool enabled,
  }) async {}
  @override
  Future<void> updateDeviceSchedule({
    required String reminderId,
    required DateTime? nextOccurrenceAt,
    required int platformNotificationId,
    required String scheduledTimezone,
  }) async {}
  @override
  Future<void> snooze(String reminderId, DateTime untilUtc) async {}
  @override
  Future<void> dismiss(String reminderId, String occurrenceKey) async {}
  @override
  Future<PrayerSession> recordSession({
    required PrayerReference prayer,
    required String timezone,
    String? revisionId,
    String? reminderId,
    String? occurrenceKey,
    String? idempotencyKey,
  }) => throw UnimplementedError();
  @override
  Future<void> retractSession(String sessionId) async {}
}
