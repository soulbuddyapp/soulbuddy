import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/altar/domain/altar_ritual.dart';
import 'package:soulbuddy/features/altar/presentation/altar_ritual_sheet.dart';
import 'package:soulbuddy/features/altar/presentation/altar_today_card.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';

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

  testWidgets('empty Altar stays compact and grounded', (tester) async {
    await tester.pumpWidget(const _App(child: AltarTodayEmptyCard()));

    expect(find.text('At your Altar'), findsOneWidget);
    expect(find.text('Keep a prayer or memory before you.'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}

Widget _app(Widget child) => _App(child: child);

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
