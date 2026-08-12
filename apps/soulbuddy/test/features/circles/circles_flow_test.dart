import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/circles/data/circle_repository.dart';
import 'package:soulbuddy/features/circles/domain/circle.dart';
import 'package:soulbuddy/features/circles/domain/circle_message.dart';
import 'package:soulbuddy/features/circles/presentation/circle_detail_screen.dart';
import 'package:soulbuddy/features/circles/presentation/circles_screen.dart';
import 'package:soulbuddy/features/circles/providers/circle_providers.dart';

void main() {
  testWidgets('guides a new user into a private Circle', (tester) async {
    final repository = _InMemoryCircleRepository();
    addTearDown(repository.close);
    await _pumpCircles(tester, repository: repository);

    expect(find.text('Circles'), findsOneWidget);
    expect(find.byKey(const Key('circles-living-vine')), findsOneWidget);
    expect(find.text('A private place to begin'), findsOneWidget);
    expect(find.text('Only you · saved on this device'), findsOneWidget);
    expect(find.text('Create a Circle'), findsOneWidget);
    expect(
      find.byKey(const Key('create-circle')).hitTestable(),
      findsOneWidget,
    );
    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getBottomLeft(find.byKey(const Key('circles-start-guide-end'))).dy,
      lessThanOrEqualTo(viewportHeight),
    );

    await tester.ensureVisible(find.byKey(const Key('create-circle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-circle')));
    await tester.pumpAndSettle();
    expect(find.text('Name your Circle'), findsOneWidget);
    expect(
      find.text('Nothing is shared from your private records.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('circle-name-field')),
      'Family prayer',
    );
    await tester.tap(find.byKey(const Key('confirm-create-circle')));
    await tester.pumpAndSettle();

    expect(find.text('Family prayer'), findsOneWidget);
    expect(find.text('Only you · this device'), findsOneWidget);
    expect(find.text('Begin the conversation'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('sends a message and labels its local delivery honestly', (
    tester,
  ) async {
    final repository = _InMemoryCircleRepository(
      initialCircles: [
        Circle(
          id: 'circle-1',
          name: 'Family prayer',
          memberCount: 1,
          createdAt: DateTime.utc(2026, 8, 12),
          updatedAt: DateTime.utc(2026, 8, 12),
        ),
      ],
    );
    addTearDown(repository.close);
    await _pumpCircles(tester, repository: repository);

    await tester.tap(find.text('Family prayer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('circle-message-field')),
      'Please pray for wisdom.',
    );
    await tester.tap(find.byKey(const Key('send-circle-message')));
    await tester.pumpAndSettle();

    expect(find.text('Please pray for wisdom.'), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(repository.lastMessage, 'Please pray for wisdom.');
  });

  testWidgets('keeps Circle creation open while the local write is pending', (
    tester,
  ) async {
    final repository = _DelayedCircleRepository();
    addTearDown(repository.release);
    addTearDown(repository.close);
    await _pumpCircles(tester, repository: repository);

    await tester.ensureVisible(find.byKey(const Key('create-circle')));
    await tester.tap(find.byKey(const Key('create-circle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('circle-name-field')),
      'Close friends',
    );
    await tester.tap(find.byKey(const Key('confirm-create-circle')));
    await tester.pump();
    await repository.started.future;

    await tester.tapAt(const Offset(8, 8));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Name your Circle'), findsOneWidget);
    expect(find.text('Creating…'), findsOneWidget);

    repository.release();
    await tester.pumpAndSettle();
    expect(find.text('Close friends'), findsOneWidget);
    expect(find.text('Begin the conversation'), findsOneWidget);
  });

  testWidgets('does not create twice when submit is repeated', (tester) async {
    final repository = _DelayedCircleRepository();
    addTearDown(repository.release);
    addTearDown(repository.close);
    await _pumpCircles(tester, repository: repository);

    await tester.tap(find.byKey(const Key('create-circle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('circle-name-field')),
      'Close friends',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await repository.started.future;

    expect(repository.createCalls, 1);
    repository.release();
    await tester.pumpAndSettle();
    expect(find.text('Close friends'), findsOneWidget);
  });

  testWidgets('does not expose a composer for an unavailable Circle', (
    tester,
  ) async {
    final repository = _InMemoryCircleRepository();
    addTearDown(repository.close);
    await _pumpCircles(
      tester,
      repository: repository,
      initialLocation: '/circles/not-mine',
    );

    expect(find.text('Circle unavailable'), findsOneWidget);
    expect(find.byKey(const Key('circle-message-field')), findsNothing);
    expect(find.byKey(const Key('send-circle-message')), findsNothing);
  });

  testWidgets('fits the normal empty state above the real shell navigation', (
    tester,
  ) async {
    final repository = _InMemoryCircleRepository();
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpCircles(
      tester,
      repository: repository,
      includeShellNavigation: true,
    );

    final guideBottom = tester
        .getBottomLeft(find.byKey(const Key('circles-start-guide-end')))
        .dy;
    final navigationTop = tester
        .getTopLeft(find.byKey(const Key('test-shell-navigation')))
        .dy;
    expect(guideBottom, lessThanOrEqualTo(navigationTop));
    expect(
      find.byKey(const Key('create-circle')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('remains usable at 200% text scale on a small phone', (
    tester,
  ) async {
    final repository = _InMemoryCircleRepository();
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpCircles(
      tester,
      repository: repository,
      textScaler: const TextScaler.linear(2),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('create-circle')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getSize(find.byKey(const Key('create-circle'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Circle detail remains usable at 200% text scale', (
    tester,
  ) async {
    final repository = _InMemoryCircleRepository(
      initialCircles: [
        Circle(
          id: 'circle-1',
          name: 'Family prayer',
          memberCount: 1,
          createdAt: DateTime.utc(2026, 8, 12),
          updatedAt: DateTime.utc(2026, 8, 12),
        ),
      ],
    );
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpCircles(
      tester,
      repository: repository,
      initialLocation: '/circles/circle-1',
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('Only you · this device'), findsOneWidget);
    expect(find.byKey(const Key('circle-message-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCircles(
  WidgetTester tester, {
  required CircleRepository repository,
  TextScaler textScaler = TextScaler.noScaling,
  String initialLocation = '/circles',
  bool includeShellNavigation = false,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/circles',
        builder: (context, state) => Scaffold(
          body: const CirclesScreen(),
          bottomNavigationBar: includeShellNavigation
              ? NavigationBar(
                  key: Key('test-shell-navigation'),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.circle_outlined),
                      label: 'Circles',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      label: 'Settings',
                    ),
                  ],
                )
              : null,
        ),
        routes: [
          GoRoute(
            path: ':circleId',
            builder: (context, state) => Scaffold(
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
        circleRepositoryProvider.overrideWith((ref) async => repository),
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

class _InMemoryCircleRepository implements CircleRepository {
  _InMemoryCircleRepository({List<Circle> initialCircles = const []})
    : _circles = List.of(initialCircles) {
    _circlesController.add(List.unmodifiable(_circles));
  }

  final _circlesController = StreamController<List<Circle>>.broadcast();
  final _messageControllers = <String, StreamController<List<CircleMessage>>>{};
  final List<Circle> _circles;
  String? lastMessage;

  @override
  Future<String> createCircle(String name) async {
    final circle = Circle(
      id: 'circle-${_circles.length + 1}',
      name: name.trim(),
      memberCount: 1,
      createdAt: DateTime.utc(2026, 8, 12),
      updatedAt: DateTime.utc(2026, 8, 12),
    );
    _circles.add(circle);
    _circlesController.add(List.unmodifiable(_circles));
    return circle.id;
  }

  @override
  Future<void> sendMessage(String circleId, String body) async {
    lastMessage = body.trim();
    final controller = _messageController(circleId);
    controller.add([
      CircleMessage(
        id: 'message-1',
        circleId: circleId,
        body: lastMessage!,
        createdAt: DateTime.utc(2026, 8, 12),
        isMine: true,
        delivery: CircleMessageDelivery.onThisDevice,
      ),
    ]);
  }

  @override
  Stream<Circle?> watchCircle(String circleId) async* {
    yield _circles.where((circle) => circle.id == circleId).firstOrNull;
    yield* _circlesController.stream.map(
      (circles) => circles.where((circle) => circle.id == circleId).firstOrNull,
    );
  }

  @override
  Stream<List<Circle>> watchCircles() async* {
    yield List.unmodifiable(_circles);
    yield* _circlesController.stream;
  }

  @override
  Stream<List<CircleMessage>> watchMessages(String circleId) async* {
    yield const [];
    yield* _messageController(circleId).stream;
  }

  StreamController<List<CircleMessage>> _messageController(String circleId) =>
      _messageControllers.putIfAbsent(
        circleId,
        () => StreamController<List<CircleMessage>>.broadcast(),
      );

  Future<void> close() async {
    await _circlesController.close();
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
  }
}

class _DelayedCircleRepository extends _InMemoryCircleRepository {
  final started = Completer<void>();
  final _release = Completer<void>();
  var createCalls = 0;

  @override
  Future<String> createCircle(String name) async {
    createCalls += 1;
    if (!started.isCompleted) started.complete();
    await _release.future;
    return super.createCircle(name);
  }

  void release() {
    if (!_release.isCompleted) _release.complete();
  }
}
