import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/commitments/application/commitment_audio.dart';
import 'package:soulbuddy/features/commitments/data/commitment_journey_practice_draft_repository.dart';
import 'package:soulbuddy/features/commitments/data/commitment_journey_progress_repository.dart';
import 'package:soulbuddy/features/commitments/data/commitment_finalization_recovery_repository.dart';
import 'package:soulbuddy/features/commitments/data/commitment_repository.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_journey_screen.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_summary_screen.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_audio_reader.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_invitation_view.dart';
import 'package:soulbuddy/features/commitments/providers/commitment_providers.dart';

class _ProgressRepository implements CommitmentJourneyProgressRepository {
  final loading = Completer<CommitmentProgressLoadResult>();
  final saving = Completer<void>();
  final writes = <CommitmentJourneyProgress>[];
  @override
  Future<CommitmentProgressLoadResult> load() => loading.future;
  @override
  Future<void> save(CommitmentJourneyProgress value) {
    writes.add(value);
    return saving.future;
  }

  @override
  Future<void> clear() async {}
}

class _PracticeRepository implements CommitmentJourneyPracticeDraftRepository {
  final writes = <List<CommitmentPracticeDraft>>[];
  @override
  Future<List<CommitmentPracticeDraft>> load() async => const [];
  @override
  Future<void> save(List<CommitmentPracticeDraft> practices) async {
    writes.add(practices);
  }

  @override
  Future<void> remove(String id) async {}
  @override
  Future<void> clear() async {}
}

class _RecoveryRepository implements CommitmentFinalizationRecoveryRepository {
  @override
  Future<String?> resolve() async => null;
  @override
  Future<void> acknowledge(String commitmentId) async {}
}

class _EmptyCommitmentRepository implements CommitmentRepository {
  @override
  Stream<Commitment?> watchPrimary() => Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Audio extends ChangeNotifier implements CommitmentAudio {
  @override
  bool complete = false;
  @override
  bool playing = false;
  @override
  bool unavailable = false;
  @override
  double speed = .85;
  @override
  Duration position = Duration.zero;
  @override
  CommitmentAudioAsset? asset;
  double volume = 1;
  int starts = 0, pauses = 0;
  @override
  Future<void> play(String id, {double volume = 1, bool loop = false}) async {
    starts++;
    this.volume = volume;
    playing = true;
    complete = false;
    notifyListeners();
  }

  @override
  Future<void> playPath(String path, {double volume = 1, bool loop = false}) =>
      play(path, volume: volume, loop: loop);
  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> resume() async {
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> stop() => pause();
  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'all emergency transcript fallbacks match the approved media catalog',
    () async {
      final catalog =
          jsonDecode(
                File(
                  'assets/audio/commitments/catalog_v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final entry
          in (catalog['assets'] as List).cast<Map<String, dynamic>>()) {
        if (entry['transcript'] == null) continue;
        final reading = await loadCommitmentReading(
          entry['id'] as String,
          catalogLoader: (_) async => throw StateError('unavailable'),
          textLoader: (_) async => throw StateError('unavailable'),
        );
        expect(reading.transcript, entry['transcript']);
        expect(reading.path, isEmpty);
      }
    },
  );

  test(
    'catalog failure retains the independently bundled full transcript',
    () async {
      var requested = '';
      final reading = await loadCommitmentReading(
        'readiness_v1',
        catalogLoader: (_) async => throw StateError('unavailable'),
        textLoader: (path) async {
          requested = path;
          return 'Complete reviewed teaching.';
        },
      );
      expect(requested, 'assets/audio/commitments/readiness_v1.txt');
      expect(reading.transcript, 'Complete reviewed teaching.');
      expect(reading.path, isEmpty);
    },
  );

  testWidgets(
    'muting preserves the invitation timeline and narration captions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final voice = _Audio(), music = _Audio(), bell = _Audio();
      var elapsed = Duration.zero;
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommitmentInvitationView(
                voice: voice,
                music: music,
                bell: bell,
                elapsed: () => elapsed,
                onContinue: () {
                  continued = true;
                },
                onReadiness: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(voice.starts, 0);
      await tester.tap(find.text('Play the invitation'));
      await tester.pump();
      await tester.tap(find.text('Mute'));
      await tester.pump();
      expect(voice.volume, 0);
      expect(voice.playing, true);
      elapsed = const Duration(seconds: 9);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Receive what God has already given.'), findsOneWidget);
      expect(music.starts, 1);
      expect(music.volume, 0);
      voice.position = const Duration(seconds: 4);
      voice.notifyListeners();
      await tester.pump();
      expect(find.byType(CommitmentTranscript), findsOneWidget);
      final transcript = tester.widget<CommitmentTranscript>(
        find.byType(CommitmentTranscript),
      );
      expect(transcript.position, const Duration(seconds: 4));
      expect(transcript.playing, true);
      await tester.tap(find.text('Unmute'));
      await tester.pump();
      expect(voice.volume, 1);
      expect(music.volume, .14);
      await tester.tap(find.text('Skip to quiet place'));
      await tester.pump();
      expect(continued, true);
      expect(voice.playing, false);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('long commitment names remain readable at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final name = List.filled(4, 'Faithful in every season.').join(' ');
    final at = DateTime(2026, 9, 26);
    final details = CommitmentDetails(
      commitment: Commitment(
        id: 'commitment',
        ownerId: 'owner',
        journeySlot: CommitmentJourneySlot.primary,
        goalId: 'goal',
        name: name,
        keyNeedOne: 'Patience',
        keyNeedTwo: 'Wisdom',
        keyNeedThree: 'Courage',
        calling: 'Serve faithfully.',
        guideId: CommitmentGuideId.peace,
        createdAt: at,
        updatedAt: at,
      ),
      practices: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commitmentDetailsProvider(
            'commitment',
          ).overrideWith((ref) => Stream.value(details)),
          commitmentSessionsProvider(
            'commitment',
          ).overrideWith((ref) => Stream.value([])),
          commitmentRecoveryRepositoryProvider.overrideWith(
            (ref) async => _RecoveryRepository(),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: CommitmentSummaryScreen(commitmentId: 'commitment'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: name.length),
    );
    expect(
      boxes.last.bottom,
      lessThanOrEqualTo(paragraph.size.height),
      reason:
          'All title lines must fit; the artwork must yield before the commitment name clips.',
    );
  });
  testWidgets('Not now cannot overwrite a draft before it finishes loading', (
    tester,
  ) async {
    final progress = _ProgressRepository();
    final practices = _PracticeRepository();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const CommitmentJourneyScreen()),
        GoRoute(path: '/goals', builder: (_, _) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commitmentRepositoryProvider.overrideWith(
            (ref) async => _EmptyCommitmentRepository(),
          ),
          commitmentJourneyProgressRepositoryProvider.overrideWith(
            (ref) async => progress,
          ),
          commitmentPracticeDraftRepositoryProvider.overrideWith(
            (ref) async => practices,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pump();
    final progressWrites = progress.writes.length;
    final practiceWrites = practices.writes.length;
    await tester.pumpWidget(const SizedBox());
    progress.saving.complete();
    progress.loading.complete(const CommitmentProgressLoadResult());
    await tester.pump();
    expect(
      progressWrites,
      0,
      reason:
          'An unloaded draft must never be replaced with the empty initial form.',
    );
    expect(
      practiceWrites,
      0,
      reason: 'Existing practices must survive leaving during draft loading.',
    );
  });

  testWidgets('schedule fields fit compact screens at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CommitmentScheduleFields(
                progress: const CommitmentJourneyProgress(
                  frequency: CommitmentMeditationFrequency.daily,
                  localTime: '07:00',
                  timezone: 'UTC',
                  durationMinutes: 10,
                  reminderMode: CommitmentReminderMode.voice,
                ),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
