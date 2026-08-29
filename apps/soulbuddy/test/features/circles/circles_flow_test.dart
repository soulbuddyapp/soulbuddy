import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/circles/data/circle_directory_repository.dart';
import 'package:soulbuddy/features/circles/data/legacy_circle_migration_repository.dart';
import 'package:soulbuddy/features/circles/domain/circle.dart';
import 'package:soulbuddy/features/circles/domain/legacy_circle.dart';
import 'package:soulbuddy/features/circles/presentation/circle_detail_screen.dart';
import 'package:soulbuddy/features/circles/presentation/circles_screen.dart';
import 'package:soulbuddy/features/circles/providers/circle_providers.dart';
import 'package:soulbuddy/features/record/data/encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';

void main() {
  testWidgets('discovers external Circles and exposes no chat composer', (
    tester,
  ) async {
    final repository = _FakeDirectoryRepository([_publicCircle()]);
    await _pumpCircles(tester, repository: repository);

    expect(find.text('Find people to walk with.'), findsOneWidget);
    expect(find.text('Accountability'), findsWidgets);
    expect(find.text('Daily Exhortation'), findsOneWidget);
    expect(find.text('Bible Study'), findsOneWidget);
    expect(find.text('Walk together'), findsOneWidget);
    expect(find.text('Conversation happens in Telegram'), findsNothing);
    expect(find.byKey(const Key('circle-message-field')), findsNothing);
    expect(find.byKey(const Key('send-circle-message')), findsNothing);
  });

  testWidgets(
    'Circle detail opens the external provider and explains ownership',
    (tester) async {
      final repository = _FakeDirectoryRepository([_publicCircle()]);
      Uri? opened;
      await _pumpCircles(
        tester,
        repository: repository,
        initialLocation: '/circles/circle-public-1',
        launcher: (uri) async {
          opened = uri;
          return true;
        },
      );

      expect(
        find.textContaining('Conversation happens in Telegram'),
        findsOneWidget,
      );
      expect(find.textContaining('not its chat'), findsOneWidget);
      expect(find.byKey(const Key('circle-message-field')), findsNothing);
      await tester.tap(find.byKey(const Key('open-external-circle')));
      await tester.pump();
      expect(opened, Uri.parse('https://t.me/+walk-together'));
    },
  );

  testWidgets('creates a Circle from purpose and external group link', (
    tester,
  ) async {
    final repository = _FakeDirectoryRepository([]);
    await _pumpCircles(tester, repository: repository);

    await tester.tap(find.byKey(const Key('create-circle')));
    await tester.pumpAndSettle();
    expect(find.text('Create a Circle'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('circle-name-field')),
      'Close friends',
    );
    await tester.enterText(
      find.byKey(const Key('circle-description-field')),
      'Walk together through a difficult season.',
    );
    await tester.enterText(
      find.byKey(const Key('circle-open-url-field')),
      'https://t.me/+close-friends',
    );
    final createButton = find.byKey(const Key('confirm-create-circle'));
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(repository.created?.name, 'Close friends');
    expect(repository.created?.visibility, CircleVisibility.unlisted);
    expect(repository.created?.status, CircleStatus.active);
    expect(find.text('Close friends'), findsOneWidget);
    expect(find.textContaining('not its chat'), findsOneWidget);
    expect(find.byKey(const Key('circle-message-field')), findsNothing);
  });

  testWidgets(
    'rejects a provider-mismatched group link before repository create',
    (tester) async {
      final repository = _FakeDirectoryRepository([]);
      await _pumpCircles(tester, repository: repository);

      await tester.tap(find.byKey(const Key('create-circle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('circle-name-field')),
        'Close friends',
      );
      await tester.enterText(
        find.byKey(const Key('circle-description-field')),
        'Walk together through a difficult season.',
      );
      await tester.enterText(
        find.byKey(const Key('circle-open-url-field')),
        'https://chat.whatsapp.com/not-telegram',
      );
      final createButton = find.byKey(const Key('confirm-create-circle'));
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Use a valid Telegram group link.'), findsOneWidget);
      expect(repository.created, isNull);
    },
  );

  testWidgets('publishes an owned draft without undoing moderator delisting', (
    tester,
  ) async {
    final repository = _FakeDirectoryRepository([
      _publicCircle(
        isOwner: true,
        status: CircleStatus.draft,
        directoryListed: false,
      ),
    ]);
    await _pumpCircles(
      tester,
      repository: repository,
      initialLocation: '/circles/circle-public-1',
    );

    expect(find.text('Publish Circle'), findsOneWidget);
    expect(
      find.textContaining('Not listed in SoulBuddy discovery'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('circle-lifecycle-action')));
    await tester.pumpAndSettle();

    expect(repository.circles.single.status, CircleStatus.active);
    expect(repository.circles.single.directoryListed, isFalse);
    expect(find.text('Pause Circle'), findsOneWidget);
    expect(
      find.textContaining('Not listed in SoulBuddy discovery'),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps legacy messages as a sensitive private Record before deleting them',
    (tester) async {
      final legacy = _FakeLegacyRepository(_legacyArchive());
      final encounters = _FakeEncounterRepository();
      await _pumpCircles(
        tester,
        repository: _FakeDirectoryRepository([]),
        legacyRepository: legacy,
        encounterRepository: encounters,
      );

      expect(find.text('Saved on this device'), findsOneWidget);
      expect(find.text('2 saved local messages'), findsOneWidget);
      await tester.tap(find.text('Keep as private Record'));
      await tester.pumpAndSettle();

      expect(encounters.lastDraft?.sensitive, isTrue);
      expect(encounters.lastDraft?.recallEnabled, isFalse);
      expect(encounters.lastDraft?.body, contains('Please pray for wisdom.'));
      expect(legacy.archive, isNull);
      expect(find.text('Kept as a private Record.'), findsOneWidget);
    },
  );

  testWidgets('old Circle deep link falls back to explicit local migration', (
    tester,
  ) async {
    final legacy = _FakeLegacyRepository(_legacyArchive());
    await _pumpCircles(
      tester,
      repository: _FakeDirectoryRepository([]),
      legacyRepository: legacy,
      initialLocation: '/circles/legacy-circle-1',
    );

    expect(find.text('Old accountability'), findsOneWidget);
    expect(
      find.textContaining('old Circle saved only on this device'),
      findsOneWidget,
    );
    expect(find.text('Keep messages as private Record'), findsOneWidget);
    expect(find.byKey(const Key('circle-message-field')), findsNothing);
  });

  testWidgets('Circles remains usable at 200 percent text on a small phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpCircles(
      tester,
      repository: _FakeDirectoryRepository([_publicCircle()]),
      textScaler: const TextScaler.linear(2),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('create-circle')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getSize(find.byKey(const Key('create-circle'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCircles(
  WidgetTester tester, {
  required CircleDirectoryRepository repository,
  LegacyCircleMigrationRepository? legacyRepository,
  EncounterRepository? encounterRepository,
  String initialLocation = '/circles',
  TextScaler textScaler = TextScaler.noScaling,
  Future<bool> Function(Uri)? launcher,
}) async {
  final legacy = legacyRepository ?? _FakeLegacyRepository(null);
  final encounters = encounterRepository ?? _FakeEncounterRepository();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/record',
        builder: (_, _) => const Scaffold(body: Text('Record')),
      ),
      GoRoute(
        path: '/circles',
        builder: (_, _) => const Scaffold(body: CirclesScreen()),
        routes: [
          GoRoute(
            path: ':circleId',
            builder: (_, state) => Scaffold(
              body: CircleDetailScreen(
                circleId: state.pathParameters['circleId']!,
              ),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        circleDirectoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        legacyCircleMigrationRepositoryProvider.overrideWith(
          (ref) async => legacy,
        ),
        encounterRepositoryProvider.overrideWith((ref) async => encounters),
        circleExternalLauncherProvider.overrideWith(
          (ref) => launcher ?? ((_) async => true),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Circle _publicCircle({
  bool isOwner = false,
  CircleStatus status = CircleStatus.active,
  bool directoryListed = true,
}) => Circle(
  publicId: 'circle-public-1',
  name: 'Walk together',
  category: CircleCategory.accountability,
  description: 'Honest accountability and prayer.',
  visibility: CircleVisibility.public,
  status: status,
  directoryListed: directoryListed,
  provider: CircleProvider.telegram,
  openUri: Uri.parse('https://t.me/+walk-together'),
  capabilities: const ['open_link'],
  isOwner: isOwner,
  updatedAt: DateTime.utc(2026, 8, 29),
);

LegacyCircleArchive _legacyArchive() => LegacyCircleArchive(
  summary: LegacyCircleSummary(
    id: 'legacy-circle-1',
    name: 'Old accountability',
    messageCount: 2,
    updatedAt: DateTime.utc(2026, 8, 12, 8, 2),
  ),
  messages: [
    LegacyCircleMessage(
      id: 'message-1',
      body: 'Please pray for wisdom.',
      createdAt: DateTime.utc(2026, 8, 12, 8, 1),
    ),
    LegacyCircleMessage(
      id: 'message-2',
      body: 'I will check in tomorrow.',
      createdAt: DateTime.utc(2026, 8, 12, 8, 2),
    ),
  ],
);

class _FakeDirectoryRepository implements CircleDirectoryRepository {
  _FakeDirectoryRepository(List<Circle> circles) : circles = List.of(circles);

  final List<Circle> circles;
  CircleDraft? created;
  String? reportedReason;

  @override
  Future<Circle> create(CircleDraft draft) async {
    created = draft;
    final circle = Circle(
      publicId: 'created-circle-1',
      name: draft.name,
      category: draft.category,
      description: draft.description,
      visibility: draft.visibility,
      status: draft.status,
      directoryListed: true,
      provider: draft.provider,
      openUri: draft.openUri,
      capabilities: const ['open_link'],
      isOwner: true,
      updatedAt: DateTime.utc(2026, 8, 29),
    );
    circles.add(circle);
    return circle;
  }

  @override
  Future<CirclePage> discover(CircleDiscoveryQuery query) async {
    final search = query.search?.toLowerCase();
    return CirclePage(
      items: circles
          .where(
            (circle) =>
                circle.directoryListed &&
                circle.visibility == CircleVisibility.public &&
                circle.status == CircleStatus.active &&
                (query.category == null || circle.category == query.category) &&
                (search == null ||
                    circle.name.toLowerCase().contains(search) ||
                    circle.description.toLowerCase().contains(search)),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Circle?> get(String publicId) async =>
      circles.where((item) => item.publicId == publicId).firstOrNull;

  @override
  Future<List<Circle>> listOwned() async =>
      circles.where((item) => item.isOwner).toList(growable: false);

  @override
  Future<void> report(String publicId, String reason) async {
    reportedReason = reason;
  }

  @override
  Future<Circle> update(String publicId, CircleUpdate update) async {
    final index = circles.indexWhere((item) => item.publicId == publicId);
    final existing = circles[index];
    final next = Circle(
      publicId: existing.publicId,
      name: update.name ?? existing.name,
      category: update.category ?? existing.category,
      description: update.description ?? existing.description,
      visibility: update.visibility ?? existing.visibility,
      status: update.status ?? existing.status,
      directoryListed: existing.directoryListed,
      provider: update.provider ?? existing.provider,
      openUri: update.openUri ?? existing.openUri,
      capabilities: existing.capabilities,
      memberCount: existing.memberCount,
      isOwner: existing.isOwner,
      updatedAt: DateTime.utc(2026, 8, 29, 1),
    );
    circles[index] = next;
    return next;
  }
}

class _FakeLegacyRepository implements LegacyCircleMigrationRepository {
  _FakeLegacyRepository(this.archive);

  LegacyCircleArchive? archive;

  @override
  Future<void> discard(String circleId) async {
    if (archive?.summary.id == circleId) archive = null;
  }

  @override
  Future<List<LegacyCircleSummary>> list() async =>
      archive == null ? const [] : [archive!.summary];

  @override
  Future<LegacyCircleArchive?> read(String circleId) async =>
      archive?.summary.id == circleId ? archive : null;
}

class _FakeEncounterRepository implements EncounterRepository {
  EncounterDraft? lastDraft;

  @override
  Future<Encounter> create(EncounterDraft draft) async {
    lastDraft = draft;
    return Encounter(
      id: 'record-1',
      ownerId: 'owner-1',
      title: draft.title,
      body: draft.body,
      occurredOn: draft.occurredOn,
      isAltar: draft.isAltar,
      createdAt: DateTime.utc(2026, 8, 29),
      updatedAt: DateTime.utc(2026, 8, 29),
      currentRevisionId: 'revision-1',
      syncState: EncounterSyncState.pending,
      memoryType: draft.memoryType,
      sensitive: draft.sensitive,
      recallEnabled: draft.recallEnabled,
      recallPaused: draft.recallPaused,
      recallIntervalDays: draft.recallIntervalDays,
    );
  }

  @override
  Future<MemoryReflection> addReflection(
    String encounterId, {
    required String body,
    required String localDate,
  }) => throw UnimplementedError();

  @override
  Future<void> archive(String encounterId) async {}

  @override
  Future<void> markAsAltar(String encounterId, {required bool value}) async {}

  @override
  Stream<List<Encounter>> watchAll() => const Stream.empty();

  @override
  Stream<List<MemoryReflection>> watchReflections(String encounterId) =>
      const Stream.empty();
}
