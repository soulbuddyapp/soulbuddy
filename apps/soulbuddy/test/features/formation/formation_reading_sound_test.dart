import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/formation/data/formation_progress_repository.dart';
import 'package:soulbuddy/features/formation/presentation/formation_reading_screen.dart';
import 'package:soulbuddy/features/formation/providers/formation_providers.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_bed_player.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';
import 'package:soulbuddy/features/scripture/domain/scripture_passage.dart';
import 'package:soulbuddy/features/scripture/providers/scripture_providers.dart';
import 'package:soulbuddy/features/record/providers/voice_note_providers.dart';
import 'package:soulbuddy/features/record/data/voice_note_repository.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/presentation/voice_notes_field.dart';
import '../../helpers/fake_inline_recorder.dart';
import 'package:soulbuddy/features/prayers/data/personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/goals/data/goal_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/formation/domain/formation_reading.dart';

void main() {
  testWidgets('changing meditation keeps the shortcut return destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(
                '/prayers/meditation/${formationReadings.first.id}',
              ),
              child: const Text('Open meditation'),
            ),
          ),
        ),
        GoRoute(
          path: '/prayers/meditation/:id',
          builder: (_, state) => FormationReadingScreen(
            readingId: state.pathParameters['id'],
            soundPlayer: _Player(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          formationProgressProvider.overrideWith(
            (_) async => const FormationProgress({}),
          ),
          scriptureRepositoryProvider.overrideWithValue(_Scripture()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open meditation'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open meditation'), findsOneWidget);
  });
  testWidgets('reflection retains meditation context and one sound selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final recorder = FakeInlineRecorder();
    final player = _Player();
    String? storedSound;
    final controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'reflection', locator: '/reflection'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          formationProgressProvider.overrideWith(
            (_) async => const FormationProgress({}),
          ),
          scriptureRepositoryProvider.overrideWithValue(_Scripture()),
          meditationSoundPreferencesProvider.overrideWithValue(
            MeditationSoundPreferencesRepository(
              read: (_) async => storedSound,
              write: (_, value) async => storedSound = value,
            ),
          ),
          voiceNotesProvider.overrideWith(
            (ref, scope) => Stream<List<VoiceNoteLink>>.value([]),
          ),
          inlineAudioCaptureControllerProvider.overrideWith(
            (ref, key) async => controller,
          ),
        ],
        child: MaterialApp(home: FormationReadingScreen(soundPlayer: player)),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<VoiceNotesField>(find.byType(VoiceNotesField));
    expect(field.noteContext.type, 'formation');
    expect(field.noteContext.field, 'reflection');
    expect(field.noteContext.id, isNotEmpty);
    await tester.tap(find.byKey(const Key('meditation-sound-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flowing water'));
    await tester.pumpAndSettle();
    expect(player.playing, MeditationSoundBed.flowingWater);
    await tester.ensureVisible(find.text('Save a private reflection'));
    await tester.tap(find.text('Save a private reflection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recorder.started, isTrue);
    expect(player.playing, isNull);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('meditation-sound-picker')), findsOneWidget);
    expect(
      find.byKey(const Key('recording-soundscape-flowingWater')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    unawaited(controller.close());
  });
  testWidgets('meditation responses remain inline', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    final prayers = _Prayers();
    final goals = _Goals();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          formationProgressProvider.overrideWith(
            (_) async => const FormationProgress({}),
          ),
          scriptureRepositoryProvider.overrideWithValue(_Scripture()),
          voiceNotesProvider.overrideWith(
            (ref, scope) => Stream<List<VoiceNoteLink>>.value([]),
          ),
          personalPrayerRepositoryProvider.overrideWith((_) async => prayers),
          goalRepositoryProvider.overrideWith((_) async => goals),
        ],
        child: MaterialApp(
          home: FormationReadingScreen(soundPlayer: _Player()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save as a prayer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Save as a prayer'));
    await tester.tap(find.text('Save as a prayer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('formation-prayer-editor')), findsOneWidget);
    expect(find.byType(FormationReadingScreen), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('formation-prayer-editor')),
        matching: find.byType(TextField),
      ),
      'My prayer',
    );
    await tester.tap(find.text('Save prayer'));
    await tester.pumpAndSettle();
    expect(prayers.body, 'My prayer');
    expect(find.text('Prayer saved'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Turn this into a Goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Turn this into a Goal'));
    await tester.tap(find.text('Turn this into a Goal'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('formation-goal-editor')), findsOneWidget);
    expect(find.byType(FormationReadingScreen), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('formation-goal-editor')),
        matching: find.byType(TextField),
      ),
      'My goal',
    );
    await tester.ensureVisible(find.text('Save goal'));
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(goals.title, 'My goal');
    expect(find.text('Goal saved'), findsOneWidget);
  });
  testWidgets(
    'reflection selection persists, stops on tab switch and restores on return',
    (tester) async {
      String? stored;
      final preferences = MeditationSoundPreferencesRepository(
        read: (_) async => stored,
        write: (_, value) async => stored = value,
      );
      final player = _Player();
      Widget app(bool visible) => ProviderScope(
        overrides: [
          meditationSoundPreferencesProvider.overrideWithValue(preferences),
          formationProgressProvider.overrideWith(
            (_) async => const FormationProgress({}),
          ),
          scriptureRepositoryProvider.overrideWithValue(_Scripture()),
        ],
        child: MaterialApp(
          home: TickerMode(
            enabled: visible,
            child: FormationReadingScreen(soundPlayer: player),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('meditation-sound-picker')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flowing water'));
      await tester.pumpAndSettle();
      expect((await preferences.load()).sound, MeditationSoundBed.flowingWater);
      expect(player.playing, MeditationSoundBed.flowingWater);
      await tester.pumpWidget(app(false));
      expect(player.playing, isNull);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(player.playing, MeditationSoundBed.flowingWater);
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No background sound'));
      await tester.pumpAndSettle();
      expect(player.playing, isNull);
      expect((await preferences.load()).sound, isNull);
    },
  );

  testWidgets(
    'sound preview also stops when a retained reading becomes hidden',
    (tester) async {
      final preferences = MeditationSoundPreferencesRepository(
        read: (_) async => null,
        write: (_, _) async {},
      );
      final player = _Player();
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meditationSoundPreferencesProvider.overrideWithValue(preferences),
            formationProgressProvider.overrideWith(
              (_) async => const FormationProgress({}),
            ),
            scriptureRepositoryProvider.overrideWithValue(_Scripture()),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, visible, _) => TickerMode(
                enabled: visible,
                child: FormationReadingScreen(soundPlayer: player),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('meditation-sound-picker')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preview Stillness'));
      await tester.pump();
      expect(player.playing, MeditationSoundBed.stillness);
      active.value = false;
      await tester.pump();
      expect(player.playing, isNull);
    },
  );
}

class _Prayers implements PersonalPrayerRepository {
  String? body;
  @override
  Future<PersonalPrayer> createOwnWords({
    required String title,
    required String body,
    String? action,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
    PrayerPurpose purpose = PrayerPurpose.daily,
  }) async {
    this.body = body;
    final now = DateTime.now();
    return PersonalPrayer(
      id: 'p',
      ownerId: 'owner',
      title: title,
      style: 'own',
      reach: 'private',
      grounding: grounding,
      purpose: purpose,
      currentRevisionId: 'r',
      body: body,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Goals implements GoalRepository {
  String? title;
  @override
  Future<Goal> create({
    required String title,
    required GoalMode mode,
    GoalStarterKey? starterKey,
    String? currentSituation,
    String? whyItMatters,
    int? position,
  }) async {
    this.title = title;
    final now = DateTime.now();
    return Goal(
      id: 'g',
      ownerId: 'owner',
      mode: mode,
      status: GoalStatus.active,
      currentRevisionId: 'r',
      position: 0,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements MeditationSoundBedPlayer {
  MeditationSoundBed? playing;
  @override
  Future<void> start(MeditationSoundBed bed, {required double volume}) async {
    playing = bed;
  }

  @override
  Future<void> stop() async {
    playing = null;
  }

  @override
  Future<void> dispose() => stop();
  @override
  Future<void> setVolume(double volume) async {}
}

class _Scripture implements ScriptureRepository {
  @override
  Future<ScripturePassage> verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) async => const ScripturePassage(
    reference: 'Romans 6:12–14',
    verses: [ScriptureVerse(number: 12, text: 'Let not sin therefore reign.')],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
