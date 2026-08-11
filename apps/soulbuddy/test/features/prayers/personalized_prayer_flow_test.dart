import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/application/prayer_generation_dispatcher.dart';
import 'package:soulbuddy/features/prayers/data/prayer_draft_api.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:soulbuddy/features/prayers/presentation/personalized_prayer_screen.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';
import 'package:soulbuddy/features/scripture/domain/scripture_passage.dart';

void main() {
  testWidgets('daily path skips Before you ask and saves every choice', (
    tester,
  ) async {
    final repository = _InMemoryGenerationRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily / affirming'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General Christian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guidance'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('prayer-request-field')),
      'Help me receive and use wisdom today.',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Before you ask'), findsNothing);
    expect(find.text('Add context'), findsOneWidget);
    expect(repository.current?.style, PrayerStyle.daily);
    expect(repository.current?.reach, PrayerReach.personal);
    expect(repository.current?.grounding, PrayerGrounding.generalChristian);
    expect(repository.current?.purpose, PrayerPurpose.guidance);
    expect(
      repository.current?.requestText,
      'Help me receive and use wisdom today.',
    );
  });

  testWidgets('situational path offers choices instead of open questions', (
    tester,
  ) async {
    final repository = _InMemoryGenerationRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await _reachRequest(tester, style: 'Situational / special');
    await tester.enterText(
      find.byKey(const Key('prayer-request-field')),
      'Give our family wisdom in this decision.',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Before you ask'), findsOneWidget);
    expect(find.text('Who should this blessing help?'), findsOneWidget);
    expect(find.text('People affected by this'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('People affected by this'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All of these'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Act faithfully'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I see no conflict'));
    await tester.pumpAndSettle();

    expect(find.text('Add context'), findsOneWidget);
    expect(repository.current?.beneficiaryChoice, 'people_affected');
    expect(repository.current?.surrenderChoice, 'all');
    expect(repository.current?.responsibilityChoice, 'act_faithfully');
    expect(repository.current?.alignmentChoice, 'no_conflict_seen');
  });

  testWidgets('explicit Encounter selection snapshots only the chosen record', (
    tester,
  ) async {
    final repository = _InMemoryGenerationRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _reachContext(tester);

    await tester.tap(find.text('Add Encounter'));
    await tester.pumpAndSettle();
    expect(find.text('A prayer I remember'), findsOneWidget);
    expect(
      find.text('Private details stay hidden until selected.'),
      findsOneWidget,
    );
    await tester.tap(find.text('A prayer I remember'));
    await tester.pumpAndSettle();

    expect(repository.current?.contexts, hasLength(1));
    final context = repository.current!.contexts.single;
    expect(context.type, PrayerContextType.encounter);
    expect(context.excerptSnapshot, 'God met me with peace.');
  });

  testWidgets(
    'explicit Scripture selection stores a structured RSVCE passage',
    (tester) async {
      final repository = _InMemoryGenerationRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _reachContext(tester);

      await tester.tap(find.text('Add Scripture'));
      await tester.pumpAndSettle();
      expect(
        find.text('RSVCE Â· Scripture. Choose up to 20 consecutive verses.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Add passage'));
      await tester.pumpAndSettle();

      final context = repository.current!.contexts.single;
      expect(context.type, PrayerContextType.scripture);
      expect(context.translation, 'RSVCE');
      expect(context.book, 'John');
      expect(context.chapter, 3);
      expect(context.firstVerse, 1);
      expect(context.lastVerse, 1);
    },
  );

  testWidgets('back navigation keeps the selected choice', (tester) async {
    final repository = _InMemoryGenerationRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily / affirming'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a prayer style'), findsOneWidget);
    final radioGroup = tester.widget<RadioGroup<PrayerStyle>>(
      find.byType(RadioGroup<PrayerStyle>),
    );
    expect(radioGroup.groupValue, PrayerStyle.daily);
  });

  testWidgets('choice layout remains usable at 200 percent text scale', (
    tester,
  ) async {
    final repository = _InMemoryGenerationRepository();
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _testApp(repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily / affirming'), findsOneWidget);
    expect(find.text('Situational / special'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choices can be reached and selected from the keyboard', (
    tester,
  ) async {
    final repository = _InMemoryGenerationRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(find.text('Who is this prayer for?'), findsOneWidget);
  });

  testWidgets('reopening a saved situational request resumes examination', (
    tester,
  ) async {
    final repository = _InMemoryGenerationRepository();
    await repository.create(
      style: PrayerStyle.situational,
      reach: PrayerReach.encompassing,
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.family,
      requestText: 'Give our family wisdom in this decision.',
    );

    await tester.pumpWidget(_testApp(repository, requestId: 'request-1'));
    await tester.pumpAndSettle();

    expect(find.text('Before you ask'), findsOneWidget);
    expect(find.text('Who should this blessing help?'), findsOneWidget);
  });

  testWidgets('provider disclosure queues only after Prepare draft', (
    tester,
  ) async {
    final repository = _InMemoryGenerationRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _reachContext(tester);

    await tester.tap(find.text('Prepare draft'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'To prepare this draft, SoulBuddy sends your choices and only the records you selected to DeepSeek. DeepSeek processes this information under its privacy policy.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(repository.queueCalls, 0);

    await tester.tap(find.text('Prepare draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Prepare draft').last);
    await tester.pumpAndSettle();

    expect(repository.queueCalls, 1);
    expect(repository.current?.consentedProvider, 'deepseek');
    expect(repository.current?.consentedDisclosureVersion, 'deepseek-1');
  });
}

Future<void> _reachRequest(
  WidgetTester tester, {
  String style = 'Daily / affirming',
}) async {
  await tester.tap(find.text(style));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Personal'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('General Christian'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Guidance'));
  await tester.pumpAndSettle();
}

Future<void> _reachContext(WidgetTester tester) async {
  await _reachRequest(tester);
  await tester.enterText(
    find.byKey(const Key('prayer-request-field')),
    'Help me walk faithfully today.',
  );
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Widget _testApp(_InMemoryGenerationRepository repository, {String? requestId}) {
  final now = DateTime.utc(2026, 8, 11, 8);
  final encounters = [
    Encounter(
      id: 'encounter-1',
      ownerId: 'owner-1',
      title: 'A prayer I remember',
      body: 'God met me with peace.',
      occurredOn: '2026-08-10',
      isAltar: true,
      createdAt: now,
      updatedAt: now,
      currentRevisionId: 'revision-1',
      syncState: EncounterSyncState.pending,
    ),
  ];
  return ProviderScope(
    overrides: [
      prayerGenerationRepositoryProvider.overrideWith(
        (ref) async => repository,
      ),
      encountersProvider.overrideWith((ref) => Stream.value(encounters)),
      scriptureRepositoryProvider.overrideWithValue(_FixtureScripture()),
      prayerGenerationDispatcherProvider.overrideWith(
        (ref) async => PrayerGenerationDispatcher(
          repository: repository,
          api: const _UnavailableDraftApi(),
          now: () => now,
        ),
      ),
    ],
    child: MaterialApp(home: PersonalizedPrayerScreen(requestId: requestId)),
  );
}

class _FixtureScripture implements ScriptureRepository {
  @override
  Future<List<String>> books() async => const ['John'];

  @override
  Future<List<int>> chapters(String book) async => const [3];

  @override
  Future<ScripturePassage> chapter({
    required String book,
    required int chapter,
  }) async => verses(book: book, chapter: chapter, firstVerse: 1, lastVerse: 2);

  @override
  Future<ScripturePassage> verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) async => ScripturePassage(
    reference: 'John 3:$firstVerse-$lastVerse',
    verses: const [
      ScriptureVerse(number: 1, text: 'First verse.'),
      ScriptureVerse(number: 2, text: 'Second verse.'),
    ],
  );
}

class _InMemoryGenerationRepository implements PrayerGenerationRepository {
  final _changes = StreamController<PrayerGenerationRequest?>.broadcast(
    sync: true,
  );
  PrayerGenerationRequest? current;
  int queueCalls = 0;

  @override
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    required String requestText,
  }) async {
    final now = DateTime.utc(2026, 8, 11, 8);
    current = PrayerGenerationRequest(
      id: 'request-1',
      ownerId: 'owner-1',
      style: style,
      reach: reach,
      grounding: grounding,
      purpose: purpose,
      requestText: requestText,
      status: PrayerGenerationStatus.editing,
      attemptCount: 0,
      contexts: const [],
      createdAt: now,
      updatedAt: now,
    );
    _changes.add(current);
    return current!;
  }

  @override
  Future<void> update(PrayerGenerationRequest request) async {
    current = request;
    _changes.add(current);
  }

  @override
  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  ) async {
    current = current!.copyWith(contexts: contexts);
    _changes.add(current);
  }

  @override
  Stream<PrayerGenerationRequest?> watch(String id) async* {
    yield current?.id == id ? current : null;
    yield* _changes.stream;
  }

  @override
  Stream<List<PrayerGenerationRequest>> watchPending() => const Stream.empty();

  @override
  Future<bool> claim(String requestId, String attemptId, DateTime now) async =>
      false;

  @override
  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  }) async {}

  @override
  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  }) async {
    queueCalls++;
    final value = current!;
    current = PrayerGenerationRequest(
      id: value.id,
      ownerId: value.ownerId,
      style: value.style,
      reach: value.reach,
      grounding: value.grounding,
      purpose: value.purpose,
      requestText: value.requestText,
      beneficiaryChoice: value.beneficiaryChoice,
      surrenderChoice: value.surrenderChoice,
      responsibilityChoice: value.responsibilityChoice,
      alignmentChoice: value.alignmentChoice,
      status: PrayerGenerationStatus.queued,
      providerDisclosureVersion: disclosureVersion,
      consentedProvider: provider,
      consentedDisclosureVersion: disclosureVersion,
      attemptCount: value.attemptCount,
      contexts: value.contexts,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
    );
    _changes.add(current);
  }

  @override
  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  ) async {}

  @override
  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  ) async {}
}

class _UnavailableDraftApi implements PrayerDraftApi {
  const _UnavailableDraftApi();

  @override
  Future<void> acknowledge(String attemptId) async {}

  @override
  Future<PrayerGeneratedDraft> generate(
    PrayerGenerationRequest request,
    List<PrayerGenerationContext> contexts,
    String attemptId,
  ) async => throw const PrayerDraftUnavailable();
}
