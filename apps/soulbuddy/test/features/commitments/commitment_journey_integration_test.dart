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
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store_io.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/presentation/record_screen.dart';
import 'package:soulbuddy/features/record/presentation/voice_notes_field.dart';
import '../../helpers/powersync_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
      for (final channel in [
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers.global/events',
        'app.soulbuddy/screen_awake',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (_) async => null,
        );
      }
      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async {
          if (call.method == 'create') {
            final id = (call.arguments as Map)['playerId'];
            messenger.setMockMethodCallHandler(
              MethodChannel('xyz.luan/audioplayers/events/$id'),
              (_) async => null,
            );
          }
          return null;
        },
      );

      final assets = IoAudioAssetStore(
        applicationSupportDirectory: directory,
        temporaryDirectory: directory,
      );
      var takeNumber = 0;
      final container = ProviderContainer(
        overrides: [
          audioAssetStoreProvider.overrideWith((ref) async => assets),
          audioCaptureControllerProvider.overrideWith((ref) async {
            final controller = AudioCaptureController(
              recorder: _JourneyRecorder(),
              allocateTemporary: () => assets.allocateTemporary(
                takeId: 'journey-take-${takeNumber++}',
                extension: 'm4a',
              ),
            );
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

      Future<void> tapText(String text) async {
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.runAsync(() => tester.tap(target));
        await tester.pump();
      }

      Future<void> stage(String heading) => settleUntil(
        () =>
            find.text(heading).evaluate().isNotEmpty &&
            find.text('Saving…').evaluate().isEmpty,
      );
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
        String title, {
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
        await tester.ensureVisible(button);
        await tester.runAsync(() => tester.tap(button));
        await settleUntil(
          () => find.text('Start recording').evaluate().isNotEmpty,
        );
        await tapText('Start recording');
        await settleUntil(() => find.text('Stop').evaluate().isNotEmpty);
        await tapText('Stop');
        await settleUntil(
          () => find.text('Use recording').evaluate().isNotEmpty,
        );
        await tapText('Use recording');
        await settleUntil(
          () => find.byKey(const Key('encounter-title')).evaluate().isNotEmpty,
        );
        expect(find.byKey(const Key('encounter-body')), findsNothing);
        await tester.enterText(find.byKey(const Key('encounter-title')), title);
        await tapText('Save');
        await settleUntil(
          () =>
              find.byType(RecordScreen).evaluate().isEmpty &&
              find.text('Saving…').evaluate().isEmpty,
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
        () =>
            container.read(commitmentJourneyProgressRepositoryProvider.future),
      );
      final deferred = await tester.runAsync(() => progressRepo!.load());
      expect(deferred!.progress!.deferred, isTrue);
      expect(deferred.progress!.stage, CommitmentJourneyStage.needs);
      expect(deferred.progress!.keyNeedThree, 'Courage to serve');
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
        recordedDrafts!.every((row) => row['context_id'] == 'journey:primary'),
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
      expect(find.text('Grace in each conversation'), findsOneWidget);
      expect(find.text('Patience with my family'), findsOneWidget);
      expect(find.text('Courage to serve'), findsOneWidget);
      await tapText('Continue');
      await stage('What is your calling?');
      await recordAudio('calling', 'Serve my neighbors');
      await tapText('Continue');
      await stage('Small, faithful choices');
      await tapText('Record my own');
      await tester.pumpAndSettle();
      await enter('Practice title', 'Walk with a neighbor');
      await recordAudio('practice', 'Listening to my neighbor', practice: true);
      await tapText('Add');
      await tester.pumpAndSettle();
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
      await capture('summary');

      final saved = (await tester.runAsync(
        () => database.powersync.getAll('SELECT * FROM commitments'),
      ))!.single;
      final plan = (await tester.runAsync(
        () => database.powersync.getAll(
          'SELECT * FROM commitment_meditation_plans',
        ),
      ))!.single;
      final practice = (await tester.runAsync(
        () => database.powersync.getAll('SELECT * FROM commitment_practices'),
      ))!.single;
      expect(saved['name'], 'Faithful service');
      expect(saved['calling'], 'Serve my neighbors');
      expect(saved['guide_id'], 'peace');
      expect(practice['body'], 'Walk with a neighbor');
      final links = (await tester.runAsync(
        () => database.powersync.getAll('SELECT * FROM voice_note_links'),
      ))!;
      expect(links, hasLength(6));
      expect(links.every((row) => row['context_id'] == saved['id']), isTrue);
      expect(
        links.where((row) => row['field_key'] == 'practice:${practice['id']}'),
        hasLength(1),
      );
      final audioAssets = await tester.runAsync(
        () => database.powersync.getAll('SELECT * FROM memory_audio_assets'),
      );
      expect(audioAssets, hasLength(6));
      expect(plan['duration_minutes'], 10);
      expect(plan['local_time'], '07:00');
      expect(
        (await tester.runAsync(() => progressRepo!.load()))!.progress,
        isNull,
      );
      expect(
        await tester.runAsync(
          () => database.powersync.getAll('SELECT * FROM goals'),
        ),
        hasLength(1),
      );
      expect(
        await tester.runAsync(
          () => database.powersync.getAll('SELECT * FROM goal_actions'),
        ),
        hasLength(1),
      );
      expect(
        await tester.runAsync(
          () => database.powersync.getAll('SELECT * FROM goal_action_events'),
        ),
        isEmpty,
      );
      expect(
        await tester.runAsync(
          () => database.powersync.getAll(
            'SELECT * FROM commitment_meditation_sessions',
          ),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
      container.dispose();
      await tester.pump();
      var closed = false;
      final closing = database.close().then((_) => closed = true);
      await settleUntil(() => closed);
      await closing;
      await tester.runAsync(() => directory.delete(recursive: true));
    },
  );
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
