import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/core/database/app_database_provider.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_journey_screen.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_summary_screen.dart';
import 'package:soulbuddy/features/commitments/providers/commitment_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store_io.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/presentation/voice_notes_field.dart';
import '../../helpers/audio_player_mocks.dart';
import '../../helpers/powersync_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installAudioPlayerMocks);
  late Directory directory;
  late AppDatabase database;
  testWidgets(
    'audio journey restores recordings and finalizes their links exactly once',
    (tester) async {
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'commitment-journey-ui-',
        );
        database = await openTestDatabase('${directory.path}/test.db');
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('app.soulbuddy/screen_awake'),
        (_) async => null,
      );

      final assets = IoAudioAssetStore(
        applicationSupportDirectory: directory,
        temporaryDirectory: directory,
      );
      final playbackDriver = _JourneyPlaybackDriver();
      final playback = MemoryAudioPlaybackCoordinator(
        assetStore: assets,
        driver: playbackDriver,
      );
      var takeNumber = 0;
      final captureControllers = <AudioCaptureController>[];
      final container = ProviderContainer(
        overrides: [
          audioAssetStoreProvider.overrideWith((ref) async => assets),
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => playback,
          ),
          audioCaptureControllerProvider.overrideWith((ref) async {
            final controller = AudioCaptureController(
              recorder: _JourneyRecorder(),
              allocateTemporary: () => assets.allocateTemporary(
                takeId: 'journey-take-${takeNumber++}',
                extension: 'm4a',
              ),
            );
            captureControllers.add(controller);
            ref.onDispose(() => unawaited(controller.close()));
            return controller;
          }),
          inlineAudioCaptureControllerProvider.overrideWith((ref, key) async {
            final controller = AudioCaptureController(
              recorder: _JourneyRecorder(),
              allocateTemporary: () => assets.allocateTemporary(
                takeId: 'journey-take-${takeNumber++}',
                extension: 'm4a',
              ),
            );
            captureControllers.add(controller);
            ref.onDispose(() => unawaited(controller.close()));
            return controller;
          }),
          appDatabaseProvider.overrideWith((ref) async => database),
          localIdentityProvider.overrideWith(
            (ref) async => const LocalIdentity(
              ownerId: 'journey-owner',
              deviceId: 'journey-device',
            ),
          ),
          prayerDeviceTimezoneProvider.overrideWithValue(
            () async => 'Africa/Lagos',
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/welcome/commitment',
        routes: [
          GoRoute(
            path: '/welcome/commitment',
            builder: (_, _) => const CommitmentJourneyScreen(),
          ),
          GoRoute(
            path: '/goals',
            builder: (_, _) => const Scaffold(body: CommitmentGoalsEntryCard()),
          ),
          GoRoute(
            path: '/commitments/:id',
            builder: (_, state) => CommitmentSummaryScreen(
              commitmentId: state.pathParameters['id']!,
            ),
          ),
        ],
      );
      final boundary = GlobalKey();
      final baseTheme = AppTheme.light();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: baseTheme,
              routerConfig: router,
            ),
          ),
        ),
      );
      Future<void> settleUntil(bool Function() done) async {
        for (var i = 0; i < 100 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(
          done(),
          isTrue,
          reason:
              'Journey did not reach the expected stage. Visible: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | ')}',
        );
        expect(tester.takeException(), isNull);
      }

      Future<void> tapAction(Finder label, String description) async {
        final controls = find.ancestor(
          of: label,
          matching: find.byWidgetPredicate(
            (widget) =>
                (widget is ButtonStyleButton && widget.onPressed != null) ||
                (widget is ChoiceChip && widget.onSelected != null) ||
                (widget is CheckboxListTile && widget.onChanged != null) ||
                (widget is ListTile && widget.onTap != null),
          ),
        );
        // A route heading or restored player can be built before the route is
        // accepting input. Center the enabled action after any layout change,
        // and wait for its actual hit-test path without settling a live mic.
        for (var attempt = 0; attempt < 40; attempt++) {
          if (controls.evaluate().isNotEmpty) {
            await Scrollable.ensureVisible(
              tester.element(controls.last),
              alignment: .5,
            );
          }
          await tester.pump(const Duration(milliseconds: 40));
          final hittable = controls.hitTestable();
          if (hittable.evaluate().isNotEmpty) {
            await tester.runAsync(() => tester.tap(hittable.last));
            await tester.pump();
            return;
          }
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        final bounds = controls.evaluate().isEmpty
            ? 'none'
            : tester.getRect(controls.last).toString();
        fail(
          'Could not tap $description. Enabled control bounds: $bounds. '
          'Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | ')}',
        );
      }

      Future<void> tapText(String text) => tapAction(find.text(text), text);

      Future<T> waitWithPumps<T>(
        Future<T> operation, {
        required String stage,
        int maxFrames = 100,
      }) async {
        late T value;
        var completed = false;
        Object? failure;
        StackTrace? failureStack;
        unawaited(
          operation.then<void>(
            (result) {
              value = result;
              completed = true;
            },
            onError: (Object error, StackTrace stackTrace) {
              failure = error;
              failureStack = stackTrace;
              completed = true;
            },
          ),
        );
        for (var frame = 0; frame < maxFrames && !completed; frame += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(completed, isTrue, reason: 'Timed out trying to $stage.');
        if (failure case final error?) {
          Error.throwWithStackTrace(error, failureStack!);
        }
        return value;
      }

      Future<void> stage(String heading) async {
        await settleUntil(
          () =>
              find.text(heading).evaluate().isNotEmpty &&
              find.text('Saving…').evaluate().isEmpty,
        );
        stdout.writeln('Commitment journey: $heading');
      }

      Future<void> enter(String label, String value) async {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pump();
      }

      Future<void> recordAudio(
        String field,
        String _, {
        bool practice = false,
      }) async {
        final scope = practice
            ? find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(VoiceNotesField),
              )
            : find.byKey(Key('commitment-record-$field'));
        final button = find.descendant(
          of: scope,
          matching: find.text('Record'),
        );
        expect(button, findsOneWidget);
        await tapAction(button, 'Record $field');
        await settleUntil(() => find.text('Pause').evaluate().isNotEmpty);
        expect(
          find.text('Pause').hitTestable(),
          findsOneWidget,
          reason:
              'The active recorder must remain interactive while the form is blocked.',
        );
        await tapText('Pause');
        await settleUntil(() => find.text('Resume').evaluate().isNotEmpty);
        await tapText('Resume');
        await tapText('Stop');
        await settleUntil(() => find.text('Save').evaluate().isNotEmpty);
        await tapText('Save');
        await settleUntil(
          () => find
              .descendant(of: scope, matching: find.text('Record'))
              .evaluate()
              .isNotEmpty,
        );
      }

      Future<void> capture(String name) async {
        final output = Platform.environment['COMMITMENT_SCREENSHOT_DIR'];
        if (output == null) return;
        final disableShadows = debugDisableShadows;
        debugDisableShadows = false;
        await tester.runAsync(() async {
          for (final image in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(image.image, boundary.currentContext!);
          }
        });
        await tester.pump(const Duration(milliseconds: 500));
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        debugDisableShadows = disableShadows;
      }

      try {
        await stage('Skip to quiet place');
        await capture('invitation');
        await tapText('Skip to quiet place');
        await stage('A moment with God');
        await tapText('Continue');
        await stage('What do you need from God?');
        await recordAudio('needs-1', 'Grace in each conversation');
        await recordAudio('needs-2', 'Patience with my family');
        await recordAudio('needs-3', 'Courage to serve');
        // Leave immediately: the 350 ms draft debounce has not fired.
        await tapText('Not now');
        await stage('Continue your commitment');
        final progressRepo = await tester.runAsync(
          () => container.read(
            commitmentJourneyProgressRepositoryProvider.future,
          ),
        );
        final deferred = await tester.runAsync(() => progressRepo!.load());
        expect(deferred!.progress!.deferred, isTrue);
        expect(deferred.progress!.stage, CommitmentJourneyStage.needs);
        expect(deferred.progress!.keyNeedThree, 'Need 3');
        expect(
          await tester.runAsync(
            () => database.powersync.getAll('SELECT * FROM goals'),
          ),
          isEmpty,
        );
        final recordedDrafts = await tester.runAsync(
          () => database.powersync.getAll('SELECT * FROM voice_note_links'),
        );
        expect(recordedDrafts, hasLength(3));
        expect(
          recordedDrafts!.every(
            (row) => row['context_id'] == 'journey:primary',
          ),
          isTrue,
        );
        final recordedCrud = await tester.runAsync(
          () => database.powersync.getCrudBatch(),
        );
        expect(recordedCrud, isNotNull);
        expect(
          recordedCrud!.crud.any(
            (entry) =>
                entry.table == 'memory_audio_assets' ||
                entry.table == 'voice_note_links',
          ),
          isFalse,
        );

        await tapText('Continue your commitment');
        await stage('What do you need from God?');
        const restoredTitles = ['Need 1', 'Need 2', 'Need 3'];
        Finder restoredRecording(String title) => find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is RecordedMemoryPlayer && widget.title == title,
          ),
          matching: find.text(title),
        );
        await settleUntil(
          () => restoredTitles.every(
            (title) => restoredRecording(title).evaluate().length == 1,
          ),
        );
        for (final title in restoredTitles) {
          expect(restoredRecording(title), findsOneWidget);
        }
        expect(playbackDriver.playCalls, 0);
        await tapText('Continue');
        await stage('What is your calling?');
        await recordAudio('calling', 'Serve my neighbors');
        await tapText('Continue');
        await stage('Small, faithful choices');
        await tapText('Add practice');
        await settleUntil(() => find.byType(AlertDialog).evaluate().isNotEmpty);
        await enter('Practice title', 'Walk with a neighbor');
        await recordAudio(
          'practice',
          'Listening to my neighbor',
          practice: true,
        );
        await tapText('Add');
        await settleUntil(() => find.byType(AlertDialog).evaluate().isEmpty);
        await tapText('Continue');
        await stage('My declaration');
        await recordAudio('declaration', 'A faithful intention');
        await tapText('Continue');
        expect(
          find.text('Review your declaration before continuing.'),
          findsOneWidget,
        );
        await tapText('This reflects my intention');
        await tapText('Continue');
        await stage('A prayerful beginning');
        await tapText('Peace');
        await tapText('Continue');
        await stage('A regular time with God');
        expect(find.text('07:00'), findsOneWidget);
        expect(find.text('Africa/Lagos'), findsOneWidget);
        await tapText('Continue');
        await stage('Name your commitment');
        await enter('Commitment name', 'Faithful service');
        await tapText('Continue');
        await stage('Save commitment');
        expect(find.text('Faithful service'), findsOneWidget);
        await tapText('Save commitment');
        await settleUntil(
          () =>
              find.byType(CommitmentSummaryScreen).evaluate().isNotEmpty &&
              find
                  .descendant(
                    of: find.byType(CommitmentSummaryScreen),
                    matching: find.text('Faithful service'),
                  )
                  .evaluate()
                  .isNotEmpty,
        );
        stdout.writeln('Commitment journey: summary visible');
        await capture('summary');
        stdout.writeln('Commitment journey: verifying durable data');

        final saved = (await waitWithPumps(
          database.powersync.getAll('SELECT * FROM commitments'),
          stage: 'read commitments',
        )).single;
        final plan = (await waitWithPumps(
          database.powersync.getAll(
            'SELECT * FROM commitment_meditation_plans',
          ),
          stage: 'read commitment_meditation_plans',
        )).single;
        final practice = (await waitWithPumps(
          database.powersync.getAll('SELECT * FROM commitment_practices'),
          stage: 'read commitment_practices',
        )).single;
        expect(saved['name'], 'Faithful service');
        expect(saved['calling'], 'Calling');
        expect(saved['guide_id'], 'peace');
        expect(practice['body'], 'Walk with a neighbor');
        final links = await waitWithPumps(
          database.powersync.getAll('SELECT * FROM voice_note_links'),
          stage: 'read voice_note_links',
        );
        expect(links, hasLength(6));
        expect(links.every((row) => row['context_id'] == saved['id']), isTrue);
        expect(
          links.where(
            (row) => row['field_key'] == 'practice:${practice['id']}',
          ),
          hasLength(1),
        );
        final audioAssets = await waitWithPumps(
          database.powersync.getAll('SELECT * FROM memory_audio_assets'),
          stage: 'read memory_audio_assets',
        );
        expect(audioAssets, hasLength(6));
        expect(plan['duration_minutes'], 10);
        expect(plan['local_time'], '07:00');
        expect(
          (await waitWithPumps(
            progressRepo!.load(),
            stage: 'read completed journey progress',
          )).progress,
          isNull,
        );
        expect(
          await waitWithPumps(
            database.powersync.getAll('SELECT * FROM goals'),
            stage: 'read goals',
          ),
          hasLength(1),
        );
        expect(
          await waitWithPumps(
            database.powersync.getAll('SELECT * FROM goal_actions'),
            stage: 'read goal_actions',
          ),
          hasLength(1),
        );
        expect(
          await waitWithPumps(
            database.powersync.getAll('SELECT * FROM goal_action_events'),
            stage: 'read goal_action_events',
          ),
          isEmpty,
        );
        expect(
          await waitWithPumps(
            database.powersync.getAll(
              'SELECT * FROM commitment_meditation_sessions',
            ),
            stage: 'read commitment_meditation_sessions',
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        stdout.writeln('Commitment journey: cleanup');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        for (final controller in captureControllers) {
          await waitWithPumps(
            controller.close(),
            stage: 'close the journey recording',
          );
          controller.dispose();
        }
        router.dispose();
        container.dispose();
        await tester.pump();
        await waitWithPumps(playback.close(), stage: 'close restored playback');
        playback.dispose();
        await waitWithPumps(
          database.close(),
          stage: 'close the journey database',
          // PowerSync closes native watchers asynchronously on Windows.
          maxFrames: 500,
        );
        await waitWithPumps(
          directory.delete(recursive: true),
          stage: 'delete the journey test directory',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// The journey fixture persists four bytes per take, not an encoded media
/// file. Keep the real store and preparation queue; replace only the decoder.
class _JourneyPlaybackDriver implements MemoryAudioPlayerDriver {
  var playCalls = 0;

  @override
  Stream<Duration> get positionChanges => const Stream.empty();
  @override
  Stream<Duration> get durationChanges => const Stream.empty();
  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => const Stream.empty();

  @override
  Future<void> prepare(String assetId, AudioPlaybackSource source) async {
    if (source is! FileAudioPlaybackSource ||
        await File(source.path).length() != 4) {
      throw StateError('Expected the durable journey recording fixture');
    }
  }

  @override
  Future<void> play(String assetId, AudioPlaybackSource source) async {
    playCalls++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> release(String assetId) async {}
  @override
  Future<void> dispose() async {}
}

class _JourneyRecorder implements AudioRecorderGateway {
  final _amplitudes = StreamController<double>.broadcast();
  TemporaryAudio? _take;
  @override
  Stream<double> get amplitudes => _amplitudes.stream;
  @override
  bool get canPause => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(TemporaryAudio target) async {
    _take = target;
    // Audio bytes are a fixture; this integration verifies capture ownership,
    // local persistence, and context links, not hardware encoding or playback.
    await File(target.locator).writeAsBytes([1, 2, 3, 4]);
  }

  @override
  Future<AudioRecorderResult> stop() async =>
      AudioRecorderResult(locator: _take!.locator, mimeType: 'audio/mp4');
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> cancel() async {
    final path = _take?.locator;
    if (path != null && await File(path).exists()) {
      await File(path).delete();
    }
  }

  @override
  Future<void> discard(AudioRecorderResult result) async {
    if (await File(result.locator).exists()) {
      await File(result.locator).delete();
    }
  }

  @override
  Future<void> dispose() => _amplitudes.close();
}
