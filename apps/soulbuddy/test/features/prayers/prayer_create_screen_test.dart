import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/editorial/data/editorial_prayer_repository.dart';
import 'package:soulbuddy/features/editorial/domain/editorial_item.dart';
import 'package:soulbuddy/features/prayers/data/personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';
import 'package:soulbuddy/features/prayers/presentation/prayer_create_screen.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/recorded_personal_prayer_providers.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/prayers/data/recorded_personal_prayer_repository.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';

import '../../helpers/audio_player_mocks.dart';

void main() {
  setUp(installAudioPlayerMocks);
  testWidgets('purpose choice opens only a reviewed editorial prayer', (
    tester,
  ) async {
    final editorialRepository = _EditorialRepository([
      _reviewedPrayer(
        id: '0198a100-0000-7000-8000-000000000003',
        title: 'For guidance',
        purpose: PrayerPurpose.guidance,
      ),
    ]);
    final personalRepository = _PersonalRepository();
    var generationProviderReads = 0;
    await _pump(
      tester,
      editorialRepository: editorialRepository,
      personalRepository: personalRepository,
      onGenerationProviderRead: () => generationProviderReads++,
    );

    await tester.tap(find.byKey(const Key('prayer-create-purpose-guidance')));
    await tester.pumpAndSettle();

    expect(find.text('Reviewed prayer'), findsOneWidget);
    expect(find.text('For guidance'), findsOneWidget);
    expect(
      find.textContaining('Reviewed · SoulBuddy editorial'),
      findsOneWidget,
    );
    expect(generationProviderReads, 0);

    await tester.tap(
      find.byKey(
        const Key(
          'prayer-create-reviewed-0198a100-0000-7000-8000-000000000003',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('reviewed:0198a100-0000-7000-8000-000000000003'),
      findsOneWidget,
    );
    expect(generationProviderReads, 0);
    expect(personalRepository.createCalls, 0);
  });

  testWidgets('own prayer saves the recording without a long text form', (
    tester,
  ) async {
    final personalRepository = _PersonalRepository();
    final recorded = _RecordedRepository();
    var generationReads = 0;
    await _pump(
      tester,
      editorialRepository: _EditorialRepository(const []),
      personalRepository: personalRepository,
      recordedRepository: recorded,
      onGenerationProviderRead: () => generationReads++,
    );
    await tester.tap(
      find.byKey(const Key('prayer-create-purpose-difficult_time')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('prayer-create-write')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('prayer-create-speak')));
    await tester.tap(find.text('Record prayer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    final stop = find.text('Stop');
    expect(
      stop,
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((e) => e.data)
          .join(' | '),
    );
    await tester.ensureVisible(stop);
    await tester.pump();
    expect(stop.hitTestable(), findsOneWidget);
    await tester.tap(stop);
    final save = find.text('Save');
    for (var attempt = 0; attempt < 30 && save.evaluate().isEmpty; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(save, findsOneWidget);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.pump();
    expect(save.hitTestable(), findsOneWidget);
    await tester.tap(save);
    final destination = find.text('saved:recorded-1');
    for (
      var attempt = 0;
      attempt < 60 &&
          (recorded.audio == null || destination.evaluate().isEmpty);
      attempt++
    ) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      recorded.audio?.temporaryKey,
      '/private/prayer.m4a',
      reason:
          'Prayer save did not reach the repository. Visible text: '
          '${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | ')}',
    );
    expect(recorded.purpose, PrayerPurpose.difficultTime);
    expect(destination, findsOneWidget);
    expect(personalRepository.createCalls, 0);
    expect(generationReads, 0);
  });

  testWidgets('reviewed path remains usable at 320px and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      editorialRepository: _EditorialRepository([
        _reviewedPrayer(
          id: '0198a100-0000-7000-8000-000000000005',
          title: 'In need of healing',
          purpose: PrayerPurpose.healing,
        ),
      ]),
      personalRepository: _PersonalRepository(),
      onGenerationProviderRead: () {},
      textScaler: const TextScaler.linear(2),
    );

    final scrollable = find.byType(Scrollable).first;
    final healingPurpose = find.byKey(
      const Key('prayer-create-purpose-healing'),
    );
    await tester.scrollUntilVisible(
      healingPurpose,
      160,
      scrollable: scrollable,
    );
    await tester.ensureVisible(healingPurpose);
    await tester.pumpAndSettle();
    await tester.tap(healingPurpose);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('In need of healing'),
      160,
      scrollable: scrollable,
    );

    expect(find.text('In need of healing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed discard keeps inline capture open for retry', (
    tester,
  ) async {
    final recorder = _PrayerRecorder()..failCancel = true;
    await _pump(
      tester,
      editorialRepository: _EditorialRepository(const []),
      personalRepository: _PersonalRepository(),
      recorder: recorder,
      onGenerationProviderRead: () {},
    );
    await tester.tap(find.byKey(const Key('prayer-create-purpose-daily')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record prayer'));
    await tester.tap(find.text('Record prayer'));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Discard'));
    await tester.pump();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(recorder.pauseCalls, 1);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pump();
    expect(recorder.cancelCalls, 1);
    expect(find.text('Discard recording'), findsOneWidget);
    recorder.failCancel = false;
    await tester.tap(find.text('Discard recording'));
    await tester.pump();
    expect(recorder.cancelCalls, 2);
    expect(find.text('Record prayer'), findsOneWidget);
  });

  testWidgets(
    'meditation prayer keeps its context without generating a text draft',
    (tester) async {
      await _pump(
        tester,
        editorialRepository: _EditorialRepository(const []),
        personalRepository: _PersonalRepository(),
        onGenerationProviderRead: () {},
        screen: const PrayerCreateScreen(
          contextTitle: 'Forgiveness · Matthew 6:14–15',
          prayerStarter: 'Lord, help me release what I am holding.',
          initialPurpose: PrayerPurpose.guidance,
        ),
      );

      expect(find.text('From your meditation'), findsOneWidget);
      expect(find.text('Forgiveness · Matthew 6:14–15'), findsOneWidget);
      expect(find.byKey(const Key('prayer-create-own-words')), findsNothing);
      expect(find.byKey(const Key('prayer-create-speak')), findsOneWidget);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _EditorialRepository editorialRepository,
  required _PersonalRepository personalRepository,
  required VoidCallback onGenerationProviderRead,
  TextScaler? textScaler,
  _RecordedRepository? recordedRepository,
  AudioRecorderGateway? recorder,
  PrayerCreateScreen screen = const PrayerCreateScreen(),
}) async {
  final router = GoRouter(
    initialLocation: '/prayers/create',
    routes: [
      GoRoute(path: '/prayers/create', builder: (context, state) => screen),
      GoRoute(
        path: '/prayers/saved/:id',
        builder: (context, state) =>
            Text('saved:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/prayers/:id',
        builder: (context, state) =>
            Text('reviewed:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/prayers',
        builder: (context, state) => const Text('prayers'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recordedPersonalPrayerRepositoryProvider.overrideWith(
          (ref) async => recordedRepository ?? _RecordedRepository(),
        ),
        inlineAudioCaptureControllerProvider.overrideWith((ref, kind) async {
          final controller = AudioCaptureController(
            recorder: recorder ?? _PrayerRecorder(),
            allocateTemporary: () async => const TemporaryAudio(
              key: 'take',
              locator: '/private/prayer.m4a',
            ),
          );
          ref.onDispose(() => unawaited(controller.close()));
          return controller;
        }),
        editorialPrayerRepositoryProvider.overrideWith(
          (ref) async => editorialRepository,
        ),
        personalPrayerRepositoryProvider.overrideWith(
          (ref) async => personalRepository,
        ),
        prayerGenerationRepositoryProvider.overrideWith((ref) async {
          onGenerationProviderRead();
          throw StateError('Generation must not be read by the new flow.');
        }),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) {
          if (textScaler == null) return child!;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _EditorialRepository implements EditorialPrayerRepository {
  _EditorialRepository(this.items);

  final List<EditorialPrayer> items;

  @override
  Stream<List<EditorialPrayer>> watchApproved({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
  }) {
    return Stream.value(
      List.unmodifiable(
        items.where(
          (item) => purpose == null || item.prayer.purpose == purpose,
        ),
      ),
    );
  }

  @override
  Stream<EditorialPrayer?> watchApprovedPrayer(String id) {
    final matches = items.where((item) => item.prayer.id == id);
    return Stream.value(matches.isEmpty ? null : matches.first);
  }
}

class _PersonalRepository implements PersonalPrayerRepository {
  int createCalls = 0;
  String? lastTitle;
  String? lastBody;
  PrayerPurpose? lastPurpose;

  @override
  Future<PersonalPrayer> createOwnWords({
    required String title,
    required String body,
    String? action,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
    PrayerPurpose purpose = PrayerPurpose.daily,
  }) async {
    createCalls++;
    lastTitle = title;
    lastBody = body;
    lastPurpose = purpose;
    final now = DateTime.utc(2026, 8, 29);
    return PersonalPrayer(
      id: 'personal-1',
      ownerId: 'owner-1',
      title: title,
      style: PrayerStyle.situational.wireValue,
      reach: PrayerReach.personal.wireValue,
      grounding: grounding,
      purpose: purpose,
      currentRevisionId: 'revision-1',
      body: body,
      action: action,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<PersonalPrayer> accept({
    required String requestId,
    required String title,
    required String body,
    String? action,
  }) => throw UnimplementedError();

  @override
  Stream<List<PersonalPrayer>> watchAll() => const Stream.empty();

  @override
  Stream<PersonalPrayer?> watch(String id) => const Stream.empty();
}

EditorialPrayer _reviewedPrayer({
  required String id,
  required String title,
  required PrayerPurpose purpose,
}) {
  return EditorialPrayer(
    prayer: LibraryPrayer(
      id: id,
      title: title,
      body:
          'Father, keep me near you and help me take the next faithful step. Amen.',
      grounding: PrayerGrounding.generalChristian,
      purpose: purpose,
      helpfulCount: 0,
      viewerMarkedHelpful: false,
    ),
    editorial: EditorialItem(
      id: id,
      kind: EditorialContentKind.preparedPrayer,
      contentVersion: 1,
      provenance: 'soulbuddy_editorial',
      sourceRef: 'fixture:v1',
      reviewState: EditorialReviewState.approved,
      reviewedOn: DateTime.utc(2026, 8, 29),
      publishedAt: DateTime.utc(2026, 8, 29),
      tags: const ['prayer'],
    ),
  );
}

class _RecordedRepository implements RecordedPersonalPrayerRepository {
  RecordedAudioDraft? audio;
  PrayerPurpose? purpose;
  @override
  Future<PersonalPrayer> create({
    required String title,
    required RecordedAudioDraft audio,
    PrayerPurpose purpose = PrayerPurpose.daily,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
  }) async {
    this.audio = audio;
    this.purpose = purpose;
    return PersonalPrayer(
      id: 'recorded-1',
      ownerId: 'owner',
      title: title,
      style: 'situational',
      reach: 'personal',
      grounding: grounding,
      purpose: purpose,
      currentRevisionId: 'revision',
      body: '',
      contentFormat: PersonalPrayerContentFormat.audio,
      createdAt: DateTime.utc(2026, 11, 3),
      updatedAt: DateTime.utc(2026, 11, 3),
    );
  }
}

class _PrayerRecorder implements AudioRecorderGateway {
  bool failCancel = false;
  int cancelCalls = 0;
  int pauseCalls = 0;
  @override
  Stream<double> get amplitudes => const Stream.empty();
  @override
  bool get canPause => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(TemporaryAudio temporary) async {}
  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {}
  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (failCancel) throw StateError('Recorder unavailable');
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> discard(AudioRecorderResult result) async {}
  @override
  Future<AudioRecorderResult> stop() async => const AudioRecorderResult(
    locator: '/private/prayer.m4a',
    mimeType: 'audio/mp4',
  );
}
