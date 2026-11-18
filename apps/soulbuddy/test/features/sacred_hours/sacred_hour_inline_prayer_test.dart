import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_bed_player.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/data/personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/data/recorded_personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/data/voice_tablet_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/recorded_personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/voice_tablet_providers.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/sacred_hours/data/sacred_hour_repository.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hour_session_screen.dart';
import 'package:soulbuddy/features/sacred_hours/providers/sacred_hour_providers.dart';
import '../../helpers/fake_inline_recorder.dart';

void main() {
  testWidgets(
    'new prayer records in the hour and retries linking without duplication',
    (tester) async {
      const channel = MethodChannel('app.soulbuddy/sacred_hour_notification');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final recorder = FakeInlineRecorder();
      final audio = AudioCaptureController(
        recorder: recorder,
        allocateTemporary: () async =>
            const TemporaryAudio(key: 'take', locator: '/take'),
      );
      final hourRepo = _HourRepository();
      final prayers = _RecordedPrayers();
      final sound = _Sound();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sacredHourProvider(
              'hour-1',
            ).overrideWith((ref) => Stream.value(_hour)),
            sacredHourRepositoryProvider.overrideWith((ref) async => hourRepo),
            personalPrayersProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            prayerLibraryProvider.overrideWith(
              (ref, filter) => Stream.value(const []),
            ),
            recordedPersonalPrayerRepositoryProvider.overrideWith(
              (ref) async => prayers,
            ),
            personalPrayerRepositoryProvider.overrideWith(
              (ref) async => _PersonalPrayers(),
            ),
            voiceTabletRepositoryProvider.overrideWith(
              (ref) async => _Tablets(),
            ),
            inlineAudioCaptureControllerProvider.overrideWith(
              (ref, key) async => audio,
            ),
            meditationSoundPreferencesProvider.overrideWithValue(
              MeditationSoundPreferencesRepository(
                read: (_) async => null,
                write: (_, _) async {},
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: SacredHourSessionScreen(hourId: 'hour-1', soundPlayer: sound),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sacred-hour-prayer-choice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a prayer'));
      await tester.pumpAndSettle();
      expect(find.byType(SacredHourSessionScreen), findsOneWidget);
      expect(recorder.started, isFalse);
      await tester.tap(find.text('Record prayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(recorder.started, isTrue);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Retry save'), findsOneWidget);
      expect(find.text('Keep prayer'), findsOneWidget);
      expect(find.text('Discard'), findsNothing);
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(prayers.creations, 1);
      expect(hourRepo.saves, 2);
      expect(hourRepo.selected, const PrayerReference.personal('new-prayer'));
      expect(find.byType(SacredHourSessionScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      unawaited(audio.close());
    },
  );
}

final _hour = SacredHour(
  id: 'hour-1',
  ownerId: 'owner',
  purpose: SacredHourPurpose.morning,
  name: 'Morning',
  localTime: PrayerLocalTime(hour: 6, minute: 0),
  timezone: 'Africa/Lagos',
  durationMinutes: 60,
  prayerMinutes: 15,
  enabled: true,
  sound: SacredHourSound.gentleChime,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
final _prayer = PersonalPrayer(
  id: 'new-prayer',
  ownerId: 'owner',
  title: 'Prayer',
  style: 'situational',
  reach: 'personal',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.daily,
  currentRevisionId: 'revision',
  body: '',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  contentFormat: PersonalPrayerContentFormat.audio,
);

class _HourRepository implements SacredHourRepository {
  int saves = 0;
  PrayerReference? selected;
  @override
  Future<SacredHour> save(SacredHourDraft draft, {String? id}) async {
    saves++;
    if (saves == 1) throw StateError('temporary');
    selected = draft.prayer;
    return _hour;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordedPrayers implements RecordedPersonalPrayerRepository {
  int creations = 0;
  @override
  Future<PersonalPrayer> create({
    required String title,
    required RecordedAudioDraft audio,
    PrayerPurpose purpose = PrayerPurpose.daily,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
  }) async {
    creations++;
    return _prayer;
  }
}

class _PersonalPrayers implements PersonalPrayerRepository {
  @override
  Stream<PersonalPrayer?> watch(String id) => Stream.value(_prayer);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tablets implements VoiceTabletRepository {
  @override
  Stream<VoiceTablet?> watchForSource(VoiceTabletSource source) =>
      Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sound implements MeditationSoundBedPlayer {
  @override
  Future<void> start(MeditationSoundBed bed, {required double volume}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
}
