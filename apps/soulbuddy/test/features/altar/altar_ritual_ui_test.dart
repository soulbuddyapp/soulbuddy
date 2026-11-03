import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';
import 'package:soulbuddy/core/playback/spiritual_session_providers.dart';
import 'package:soulbuddy/features/altar/domain/altar_ritual.dart';
import 'package:soulbuddy/features/altar/presentation/altar_ritual_sheet.dart';
import 'package:soulbuddy/features/altar/presentation/altar_today_card.dart';
import 'package:soulbuddy/features/altar/providers/altar_ritual_providers.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';
import 'package:soulbuddy/features/prayers/providers/voice_tablet_providers.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';

void main() {
  testWidgets('keeps a Prayer Refrain as an every-day Altar ritual', (
    tester,
  ) async {
    AltarRitualDraft? saved;
    await tester.pumpWidget(
      _app(
        AltarRitualSheet(
          tablet: _tablet(withRefrain: true),
          timezoneName: 'Africa/Lagos',
          onSave: (draft) async => saved = draft,
        ),
      ),
    );

    expect(find.text('Keep on my Altar'), findsOneWidget);
    expect(
      find.text('Return to this prayer at a chosen time.'),
      findsOneWidget,
    );
    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('Prayer Refrain'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('save-altar-ritual')));
    await tester.tap(find.byKey(const Key('save-altar-ritual')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.target, AltarTarget.voiceTablet('tablet-1'));
    expect(saved!.schedule.type, AltarScheduleType.daily);
    expect(saved!.playbackMode, AltarPlaybackMode.refrain);
    expect(saved!.enableOnThisDevice, isTrue);
    expect(saved!.autoplayWhenOpened, isFalse);
  });

  testWidgets('requires at least one selected day', (tester) async {
    await tester.pumpWidget(
      _app(
        AltarRitualSheet(
          tablet: _tablet(withRefrain: true),
          timezoneName: 'Africa/Lagos',
          onSave: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Selected days'));
    await tester.pump();
    final selectedDay = find.byWidgetPredicate(
      (widget) => widget is FilterChip && widget.selected,
    );
    await tester.ensureVisible(selectedDay);
    await tester.tap(selectedDay);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-altar-ritual')));
    await tester.tap(find.byKey(const Key('save-altar-ritual')));
    await tester.pump();

    expect(find.text('Choose at least one day.'), findsOneWidget);
  });

  testWidgets('does not offer a missing Prayer Refrain', (tester) async {
    await tester.pumpWidget(
      _app(
        AltarRitualSheet(
          tablet: _tablet(withRefrain: false),
          timezoneName: 'Africa/Lagos',
          onSave: (_) async {},
        ),
      ),
    );

    expect(find.text('Prayer Refrain'), findsNothing);
    expect(find.text('Full prayer'), findsOneWidget);
  });

  testWidgets('listening is separate from confirming prayer', (tester) async {
    var listens = 0;
    var prayers = 0;
    await tester.pumpWidget(
      _app(
        AltarTodayCard(
          due: _due(),
          tablet: _tablet(withRefrain: true),
          onListen: () async => listens += 1,
          onPrayed: () async {
            prayers += 1;
            return 'session-1';
          },
        ),
      ),
    );

    expect(find.text('At your Altar'), findsOneWidget);
    expect(find.text('Morning refrain'), findsOneWidget);
    await tester.tap(find.byKey(const Key('altar-listen')));
    await tester.pump();
    expect(listens, 1);
    expect(prayers, 0);

    await tester.tap(find.byKey(const Key('altar-prayed')));
    await tester.pump();
    expect(prayers, 1);
  });

  testWidgets('Altar listening closes old playback before starting', (
    tester,
  ) async {
    final driver = _AltarAudioDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _AltarAudioStore(),
      driver: driver,
    );
    final spiritual = SpiritualSessionController();
    await _pumpPlaybackOperation(
      tester,
      coordinator.playTrack(
        const PrivateAudioTrack(
          id: 'old',
          storageKey: 'private/old.m4a',
          duration: Duration(seconds: 12),
        ),
      ),
      stage: 'start the previous audio',
    );
    await _pumpPlaybackOperation(
      tester,
      spiritual.begin(
        SpiritualSession(
          id: 'old-session',
          kind: SpiritualSessionKind.memory,
          title: 'Previous memory',
          route: '/remember/old',
          canPause: true,
          onPause: coordinator.pause,
          onResume: () async {},
          onComplete: () async {},
          onClose: coordinator.stop,
        ),
      ),
      stage: 'register the previous session',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dueAltarRitualProvider.overrideWith((ref) => Stream.value(_due())),
          voiceTabletProvider.overrideWith(
            (ref, id) => Stream.value(_tablet(withRefrain: true)),
          ),
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          spiritualSessionControllerProvider.overrideWithValue(spiritual),
        ],
        child: const _App(child: AltarReminderOverlayHost()),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(find.byKey(const Key('altar-listen')));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(driver.events, ['play:old', 'stop:old', 'play:refrain']);
    expect(coordinator.state.assetId, 'refrain');
    expect(coordinator.state.status, MemoryAudioPlaybackStatus.playing);
    expect(spiritual.state.session?.kind, SpiritualSessionKind.altar);
    await _pumpPlaybackOperation(
      tester,
      spiritual.close(),
      stage: 'close the Altar session',
    );
    await _pumpPlaybackOperation(
      tester,
      coordinator.close(),
      stage: 'dispose the playback coordinator',
      describePending: driver.describeShutdown,
    );
    expect(driver.disposeCompleted, isTrue);
    expect(driver.hasListeners, isFalse);
    spiritual.dispose();
    coordinator.dispose();
  });

  testWidgets('Undo remains available after the completed card unmounts', (
    tester,
  ) async {
    final completion = Completer<String?>();
    final showCard = ValueNotifier(true);
    addTearDown(showCard.dispose);
    var undid = false;

    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<bool>(
          valueListenable: showCard,
          builder: (context, visible, _) => visible
              ? AltarTodayCard(
                  due: _due(),
                  tablet: _tablet(withRefrain: true),
                  onListen: () async {},
                  onPrayed: () => completion.future,
                  onUndo: (_) async => undid = true,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('altar-prayed')));
    await tester.pump();
    showCard.value = false;
    await tester.pump();
    completion.complete('session-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undid, isTrue);
  });

  testWidgets('empty Altar stays compact and grounded', (tester) async {
    await tester.pumpWidget(const _App(child: AltarTodayEmptyCard()));

    expect(find.text('At your Altar'), findsOneWidget);
    expect(find.text('Keep a prayer or memory before you.'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}

Widget _app(Widget child) => _App(child: child);

Future<void> _pumpPlaybackOperation(
  WidgetTester tester,
  Future<void> operation, {
  required String stage,
  String Function()? describePending,
}) async {
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    operation.then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stackTrace) {
        failure = error;
        failureStack = stackTrace;
        completed = true;
      },
    ),
  );
  for (var frame = 0; frame < 20 && !completed; frame += 1) {
    // Closing an already-cancelled stream can return Dart's shared root-zone
    // future. Its continuation needs a real turn as well as a fake frame.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(
    completed,
    isTrue,
    reason: 'Timed out trying to $stage. ${describePending?.call() ?? ''}',
  );
  if (failure case final error?) {
    Error.throwWithStackTrace(error, failureStack!);
  }
}

class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 390, child: child)),
    ),
  );
}

VoiceTablet _tablet({required bool withRefrain}) => VoiceTablet(
  id: 'tablet-1',
  ownerId: 'owner-1',
  source: VoiceTabletSource.personal(
    prayerId: 'prayer-1',
    revisionId: 'revision-1',
  ),
  title: 'Morning refrain',
  fullAudio: _audio(VoiceTabletAudioKind.fullPrayer, 'full'),
  refrainAudio: withRefrain
      ? _audio(VoiceTabletAudioKind.refrain, 'refrain')
      : null,
  createdAt: DateTime.utc(2026, 8, 26),
  updatedAt: DateTime.utc(2026, 8, 26),
);

VoiceTabletAudio _audio(VoiceTabletAudioKind kind, String id) =>
    VoiceTabletAudio(
      id: id,
      kind: kind,
      storageKey: 'private/$id.m4a',
      mimeType: 'audio/mp4',
      duration: const Duration(seconds: 12),
      byteSize: 1200,
      waveform: const [0.2, 0.7, 0.4],
      createdAt: DateTime.utc(2026, 8, 26),
    );

DueAltarRitual _due() => DueAltarRitual(
  item: AltarItem(
    id: 'item-1',
    ownerId: 'owner-1',
    target: const AltarTarget.voiceTablet('tablet-1'),
    createdAt: DateTime.utc(2026, 8, 26),
    updatedAt: DateTime.utc(2026, 8, 26),
  ),
  ritual: AltarRitual(
    id: 'ritual-1',
    ownerId: 'owner-1',
    itemId: 'item-1',
    schedule: AltarRitualSchedule.daily(
      localTime: PrayerLocalTime(hour: 7, minute: 30),
      timezone: 'Africa/Lagos',
    ),
    playbackMode: AltarPlaybackMode.refrain,
    enabled: true,
    createdAt: DateTime.utc(2026, 8, 26),
    updatedAt: DateTime.utc(2026, 8, 26),
  ),
  occurrenceAt: DateTime.utc(2026, 8, 26, 6, 30),
  localStatus: AltarRitualLocalStatus.due,
  hasLocalAudio: true,
  autoplayWhenOpened: false,
  audioStorageKey: 'private/refrain.m4a',
);

class _AltarAudioDriver implements MemoryAudioPlayerDriver {
  final events = <String>[];
  final _durations = StreamController<Duration>(onCancel: () async {});
  final _positions = StreamController<Duration>(onCancel: () async {});
  final _statuses = StreamController<MemoryAudioDriverStatus>(
    onCancel: () async {},
  );
  String? _active;
  bool disposeCompleted = false;

  bool get hasListeners =>
      _positions.hasListener || _durations.hasListener || _statuses.hasListener;

  String describeShutdown() =>
      'Listeners (position/duration/status): ${_positions.hasListener}/'
      '${_durations.hasListener}/${_statuses.hasListener}; closed: '
      '${_positions.isClosed}/${_durations.isClosed}/${_statuses.isClosed}; '
      'driver disposal completed: $disposeCompleted.';

  @override
  Stream<Duration> get durationChanges => _durations.stream;

  @override
  Stream<Duration> get positionChanges => _positions.stream;

  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => _statuses.stream;

  @override
  Future<void> play(String assetId, AudioPlaybackSource source) async {
    _active = assetId;
    events.add('play:$assetId');
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    if (_active != null) events.add('stop:$_active');
    _active = null;
  }

  @override
  Future<void> dispose() async {
    await _durations.close();
    await _positions.close();
    await _statuses.close();
    disposeCompleted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AltarAudioStore implements AudioAssetStore {
  @override
  Future<AudioPlaybackSource?> open(String storageKey) async =>
      FileAudioPlaybackSource(storageKey);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
