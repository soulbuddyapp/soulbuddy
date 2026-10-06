import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/editorial/data/editorial_prayer_repository.dart';
import 'package:soulbuddy/features/editorial/domain/editorial_item.dart';
import 'package:soulbuddy/features/prayers/data/personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';
import 'package:soulbuddy/core/speech/sayable_field.dart';
import 'package:soulbuddy/features/prayers/presentation/prayer_create_screen.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

import '../../helpers/no_speech_recognizer.dart';

void main() {
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

  testWidgets('own words save directly without a generation request', (
    tester,
  ) async {
    final editorialRepository = _EditorialRepository(const []);
    final personalRepository = _PersonalRepository();
    var generationProviderReads = 0;
    await _pump(
      tester,
      editorialRepository: editorialRepository,
      personalRepository: personalRepository,
      onGenerationProviderRead: () => generationProviderReads++,
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.tap(
      find.byKey(const Key('prayer-create-purpose-difficult_time')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('prayer-create-write')),
      160,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('prayer-create-write')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('prayer-create-own-words')),
      160,
      scrollable: scrollable,
    );
    await tester.enterText(
      find.byKey(const Key('prayer-create-own-words')),
      'Jesus, stay near me and help me take the next faithful step.',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('prayer-create-save-own-words')),
      160,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('prayer-create-save-own-words')));
    await tester.pumpAndSettle();

    expect(personalRepository.createCalls, 1);
    expect(personalRepository.lastPurpose, PrayerPurpose.difficultTime);
    expect(
      personalRepository.lastBody,
      'Jesus, stay near me and help me take the next faithful step.',
    );
    expect(personalRepository.lastTitle, 'My prayer · Difficult time');
    expect(find.text('saved:personal-1'), findsOneWidget);
    expect(generationProviderReads, 0);
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

  testWidgets('meditation prayer opens with context and editable starter', (
    tester,
  ) async {
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
    expect(
      tester
          .widget<SayableField>(
            find.byKey(const Key('prayer-create-own-words')),
          )
          .controller
          .text,
      'Lord, help me release what I am holding.',
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _EditorialRepository editorialRepository,
  required _PersonalRepository personalRepository,
  required VoidCallback onGenerationProviderRead,
  TextScaler? textScaler,
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
        // The own-words field now offers the microphone, which resolves
        // availability when it appears.
        speechRecognizerProvider.overrideWithValue(NoSpeech()),
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
