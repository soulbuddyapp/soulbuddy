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
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_journey_screen.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_summary_screen.dart';
import 'package:soulbuddy/features/commitments/providers/commitment_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import '../../helpers/powersync_test_database.dart';
import '../../helpers/settle_until.dart' as settle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late AppDatabase database;
  testWidgets('first journey defers, restores typed answers, and finalizes once', (
    tester,
  ) async {
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
      'plugin.csdcorp.com/speech_to_text',
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

    // Real app typography for optional review captures, rather than Ahem blocks.
    await tester.runAsync(() async {
      final display = FontLoader('Source Serif 4 Display')
        ..addFont(
          rootBundle.load('assets/fonts/SourceSerif4Display-Semibold.ttf'),
        );
      await display.load();
      final body = FontLoader('Review body')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
            ),
          ),
        );
      await body.load();
      final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
      for (final pair in [
        [
          'Ahem',
          '$flutterRoot/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        ],
        [
          'MaterialIcons',
          '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ],
      ]) {
        final loader = FontLoader(pair[0])
          ..addFont(
            Future.value(
              ByteData.sublistView(await File(pair[1]).readAsBytes()),
            ),
          );
        await loader.load();
      }
    });
    final container = ProviderContainer(
      overrides: [
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
        // The journey's sayable fields resolve speech the moment they mount, and
        // the real seam answers that by asking `path_provider` and `record` for a
        // microphone this test never uses. Neither plugin is registered here, so
        // each miss costs a round trip on every stage of a journey that is
        // otherwise only about the answers. Answering directly leaves the screen
        // in the state it was in before: speech unavailable, the field writable.
        speechRecognizerProvider.overrideWithValue(_NoSpeech()),
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
            theme: baseTheme.copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: baseTheme.filledButtonTheme.style!.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    baseTheme.textTheme.labelLarge!.copyWith(
                      fontFamily: 'Review body',
                    ),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: baseTheme.outlinedButtonTheme.style!.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    baseTheme.textTheme.labelLarge!.copyWith(
                      fontFamily: 'Review body',
                    ),
                  ),
                ),
              ),
              textTheme: baseTheme.textTheme
                  .apply(fontFamily: 'Review body')
                  .copyWith(
                    headlineMedium: baseTheme.textTheme.headlineMedium,
                    titleLarge: baseTheme.textTheme.titleLarge,
                  ),
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    Future<void> settleUntil(bool Function() done) async {
      await settle.settleUntil(tester, done);
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
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
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
    await enter('Need 1', 'Grace in each conversation');
    await enter('Need 2', 'Patience with my family');
    await enter('Need 3', 'Courage to serve');
    // Leave immediately: the 350 ms draft debounce has not fired.
    await tapText('Not now');
    await stage('Continue your commitment');
    final progressRepo = await tester.runAsync(
      () => container.read(commitmentJourneyProgressRepositoryProvider.future),
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
    expect(
      await tester.runAsync(() => database.powersync.getNextCrudTransaction()),
      isNull,
    );

    await tapText('Continue your commitment');
    await stage('What do you need from God?');
    expect(find.text('Grace in each conversation'), findsOneWidget);
    expect(find.text('Patience with my family'), findsOneWidget);
    expect(find.text('Courage to serve'), findsOneWidget);
    await tapText('Continue');
    await stage('What is your calling?');
    await enter('Calling', 'Serve my neighbors with patience and hope.');
    await tapText('Continue');
    await stage('Small, faithful choices');
    await tapText('Write my own');
    await tester.pumpAndSettle();
    await enter('Practice', 'Walk with a neighbor and listen.');
    await tapText('Add');
    await tester.pumpAndSettle();
    await tapText('Continue');
    await stage('My declaration');
    await enter(
      'Declaration',
      'I offer my time to God and will serve with patience.',
    );
    await tapText('Continue');
    expect(
      find.text('Review your declaration before continuing.'),
      findsOneWidget,
    );
    await tapText('These words reflect my intention.');
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
    expect(saved['calling'], 'Serve my neighbors with patience and hope.');
    expect(saved['guide_id'], 'peace');
    expect(practice['body'], 'Walk with a neighbor and listen.');
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
  });
}

/// Speech that cannot run, answered without reaching a plugin.
///
/// `false` is what the unmocked plugins resolved to anyway, so the notice and
/// the writable field are what this journey has always been tested against.
class _NoSpeech implements SpeechRecognizer {
  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
    VoidCallback? onError,
  }) async => false;

  @override
  Future<void> listen({required void Function(String words) onWords}) async {}

  @override
  Future<void> stop() async {}
}
