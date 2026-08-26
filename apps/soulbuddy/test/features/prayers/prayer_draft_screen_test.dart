import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/data/prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/data/prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';
import 'package:soulbuddy/features/prayers/presentation/prayer_draft_screen.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

void main() {
  testWidgets('edits, removes the optional action, and saves locally first', (
    tester,
  ) async {
    final generation = _DraftGenerationRepository(_readyRequest());
    final personal = _PersonalPrayerRepository();
    await tester.pumpWidget(_app(generation, personal));
    await tester.pumpAndSettle();

    expect(find.text('Prayer draft'), findsOneWidget);
    expect(find.text('A remembered act of patience'), findsOneWidget);
    expect(find.text('John 15:9-10'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('draft-body-field')),
      'Father, keep our family truthful, patient, and faithful today. Amen.',
    );
    await _tapVisible(tester, 'Remove action');
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'Save prayer');
    await tester.pumpAndSettle();

    expect(personal.acceptedBody, contains('truthful'));
    expect(personal.acceptedAction, isNull);
    expect(generation.current.draftAction, isNull);
  });

  testWidgets('Use today accepts before selecting the personal prayer', (
    tester,
  ) async {
    final generation = _DraftGenerationRepository(_readyRequest());
    final personal = _PersonalPrayerRepository();
    final today = _TodayRepository();
    await tester.pumpWidget(_app(generation, personal, today: today));
    await tester.pumpAndSettle();

    await _tapVisible(tester, 'Use today');
    await tester.pumpAndSettle();

    expect(personal.acceptCalls, 1);
    expect(today.selected, const PrayerReference.personal('personal-1'));
    expect(today.includeAction, isTrue);
  });

  testWidgets('persists edits across leave and reopen', (tester) async {
    final generation = _DraftGenerationRepository(_readyRequest());
    final personal = _PersonalPrayerRepository();
    await tester.pumpWidget(_app(generation, personal));
    await tester.pumpAndSettle();
    const edited =
        'Father, keep us near you and ready to serve in peace. Amen.';

    await tester.enterText(find.byKey(const Key('draft-body-field')), edited);
    await tester.tap(find.text('Prayer draft'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(generation, personal));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('draft-body-field')),
    );
    expect(field.controller?.text, edited);
  });

  testWidgets('asks before replacing a draft that has user edits', (
    tester,
  ) async {
    final generation = _DraftGenerationRepository(_readyRequest());
    final personal = _PersonalPrayerRepository();
    await tester.pumpWidget(_app(generation, personal));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('draft-title-field')),
      'My edited title',
    );
    await _tapVisible(tester, 'Prepare another draft');
    await tester.pumpAndSettle();

    expect(find.text('Replace your edits?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(generation.queueCalls, 0);
  });

  testWidgets('remains usable with 200 percent text scaling', (tester) async {
    final generation = _DraftGenerationRepository(_readyRequest());
    final personal = _PersonalPrayerRepository();

    await tester.pumpWidget(
      _app(generation, personal, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft-title-field')), findsOneWidget);
    await _tapVisible(tester, 'Save prayer');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapVisible(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget _app(
  _DraftGenerationRepository generation,
  _PersonalPrayerRepository personal, {
  _TodayRepository? today,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [
      prayerGenerationRepositoryProvider.overrideWith(
        (ref) async => generation,
      ),
      personalPrayerRepositoryProvider.overrideWith((ref) async => personal),
      prayerRepositoryProvider.overrideWith(
        (ref) async => today ?? _TodayRepository(),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const PrayerDraftScreen(requestId: 'request-1'),
    ),
  );
}

PrayerGenerationRequest _readyRequest() {
  final now = DateTime.utc(2026, 8, 11, 8);
  return PrayerGenerationRequest(
    id: 'request-1',
    ownerId: 'owner-1',
    style: PrayerStyle.situational,
    reach: PrayerReach.encompassing,
    grounding: PrayerGrounding.generalChristian,
    purpose: PrayerPurpose.family,
    requestText: 'Give our family wisdom.',
    status: PrayerGenerationStatus.ready,
    draftTitle: 'For faithful wisdom',
    draftBody: 'Father, keep our family truthful and faithful. Amen.',
    draftAction: 'Listen before choosing a response.',
    generatedTitle: 'For faithful wisdom',
    generatedBody: 'Father, keep our family truthful and faithful. Amen.',
    generatedAction: 'Listen before choosing a response.',
    promptVersion: '1',
    attemptCount: 1,
    contexts: const [
      PrayerGenerationContext.encounter(
        sourceId: 'encounter-1',
        displayLabel: 'A remembered act of patience',
        excerptSnapshot: 'We listened before answering.',
      ),
      PrayerGenerationContext.scripture(
        sourceId: 'John-15-9-10',
        displayLabel: 'John 15:9-10',
        excerptSnapshot: '9 Remain in my love.',
        translation: 'RSVCE',
        book: 'John',
        chapter: 15,
        firstVerse: 9,
        lastVerse: 10,
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

class _DraftGenerationRepository implements PrayerGenerationRepository {
  _DraftGenerationRepository(this.current);

  PrayerGenerationRequest current;
  int queueCalls = 0;

  @override
  Stream<PrayerGenerationRequest?> watch(String id) => Stream.value(current);

  @override
  Future<void> update(PrayerGenerationRequest request) async {
    current = request;
  }

  @override
  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  }) async {
    queueCalls++;
  }

  @override
  Future<bool> claim(String requestId, String attemptId, DateTime now) async =>
      false;

  @override
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    PrayerLanguagePreference? languagePreference,
    required String requestText,
  }) => throw UnimplementedError();

  @override
  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  }) => throw UnimplementedError();

  @override
  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  ) => throw UnimplementedError();

  @override
  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  ) => throw UnimplementedError();

  @override
  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  ) => throw UnimplementedError();

  @override
  Stream<List<PrayerGenerationRequest>> watchPending() => const Stream.empty();
}

class _PersonalPrayerRepository implements PersonalPrayerRepository {
  int acceptCalls = 0;
  String? acceptedBody;
  String? acceptedAction;

  @override
  Future<PersonalPrayer> accept({
    required String requestId,
    required String title,
    required String body,
    String? action,
  }) async {
    acceptCalls++;
    acceptedBody = body;
    acceptedAction = action;
    final now = DateTime.utc(2026, 8, 11, 8);
    return PersonalPrayer(
      id: 'personal-1',
      ownerId: 'owner-1',
      title: title,
      style: 'situational',
      reach: 'encompassing',
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.family,
      currentRevisionId: 'revision-1',
      body: body,
      action: action,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Stream<PersonalPrayer?> watch(String id) => const Stream.empty();

  @override
  Stream<List<PersonalPrayer>> watchAll() => const Stream.empty();
}

class _TodayRepository implements PrayerRepository {
  PrayerReference? selected;
  bool? includeAction;

  @override
  Future<void> selectForToday(
    PrayerReference prayer, {
    required bool includeAction,
  }) async {
    selected = prayer;
    this.includeAction = includeAction;
  }

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required PrayerReference expectedPrayer,
    required bool value,
  }) async {}

  @override
  Future<void> setHelpful(String prayerId, {required bool value}) async {}

  @override
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
  }) => const Stream.empty();

  @override
  Stream<LibraryPrayer?> watchPrayer(String id) => const Stream.empty();

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) => const Stream.empty();
}
