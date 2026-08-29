import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/core/database/app_database_provider.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';

const _databaseName = 'soulbuddy-audio-integration.db';
const _identity = LocalIdentity(
  ownerId: 'offline-audio-integration-owner',
  deviceId: 'offline-audio-integration-device',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a spoken memory and its private bytes survive a real reopen', (
    tester,
  ) async {
    final databasePath = await _testDatabasePath();
    final firstContainer = _newContainer(databasePath);
    final firstDatabase = await firstContainer.read(appDatabaseProvider.future);
    await _clearOwnedRows(firstDatabase);

    appRouter.go('/record');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: firstContainer,
        child: const SoulBuddyApp(),
      ),
    );
    await _pumpUntil(tester, find.byKey(const Key('record-speak')));
    _expectNoException(tester, 'opening Record');

    await tester.tap(find.byKey(const Key('record-speak')));
    await _pumpUntil(tester, find.text('Start recording'));
    await tester.tap(find.text('Start recording'));
    await _pumpUntil(
      tester,
      find.bySemanticsLabel('Stop and review recording'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await tester.pump();
    _expectNoException(tester, 'recording fake microphone audio');

    await tester.tap(find.bySemanticsLabel('Stop and review recording'));
    await _pumpUntil(tester, find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _pumpUntil(tester, find.text('Save'));
    await tester.ensureVisible(find.text('Encounter'));
    await tester.tap(find.text('Encounter'));
    await tester.enterText(
      find.byKey(const Key('encounter-title')),
      'Help spoken and remembered',
    );
    await tester.enterText(
      find.byKey(const Key('encounter-body')),
      'I want to return to what God showed me here.',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await _pumpUntil(tester, find.text('Record saved'));
    _expectNoException(tester, 'saving an Encounter with private audio');

    final encounterRows = await firstDatabase.powersync.getAll(
      'SELECT id, title, body FROM encounters WHERE owner_id = ?',
      [_identity.ownerId],
    );
    expect(encounterRows, hasLength(1));
    expect(encounterRows.single['title'], 'Help spoken and remembered');
    expect(
      encounterRows.single['body'],
      'I want to return to what God showed me here.',
    );
    final encounterId = encounterRows.single['id'] as String;
    final firstAudio = await _ownedAudio(firstContainer, encounterId);
    final firstEvidence = await _audioEvidence(
      firstContainer,
      firstAudio.storageKey,
    );
    expect(firstEvidence, isNotEmpty);

    appRouter.go('/remember');
    await _pumpUntil(tester, find.textContaining('Voice memory'));
    await _pumpUntil(tester, find.text('Play'));
    await _tapVisible(tester, find.text('Play').first);
    await _expectPlayback(firstContainer, tester, firstAudio.id);
    _expectNoException(tester, 'playing the saved audio');

    await _closeApp(tester, firstContainer, firstDatabase);

    final reopenedContainer = _newContainer(databasePath);
    final reopenedDatabase = await reopenedContainer.read(
      appDatabaseProvider.future,
    );
    final reopenedAudio = await _ownedAudio(reopenedContainer, encounterId);
    expect(reopenedAudio.id, firstAudio.id);
    expect(reopenedAudio.byteSize, firstAudio.byteSize);
    expect(
      await _audioEvidence(reopenedContainer, reopenedAudio.storageKey),
      firstEvidence,
    );

    appRouter.go('/remember');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: reopenedContainer,
        child: const SoulBuddyApp(),
      ),
    );
    await _pumpUntil(tester, find.textContaining('Voice memory'));
    await _pumpUntil(tester, find.text('Play'));
    await _tapVisible(tester, find.text('Play').first);
    await _expectPlayback(reopenedContainer, tester, reopenedAudio.id);
    _expectNoException(tester, 'playing after the database reopen');

    await _closeApp(tester, reopenedContainer, reopenedDatabase);
  });
}

ProviderContainer _newContainer(String databasePath) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith(
      (ref) => AppDatabase.open(path: databasePath),
    ),
    localIdentityProvider.overrideWith((ref) async => _identity),
  ],
);

Future<void> _clearOwnedRows(AppDatabase database) async {
  await database.powersync.execute(
    'DELETE FROM memory_audio_assets WHERE owner_id = ?',
    [_identity.ownerId],
  );
  await database.powersync.execute(
    'DELETE FROM encounter_revisions WHERE owner_id = ?',
    [_identity.ownerId],
  );
  await database.powersync.execute(
    'DELETE FROM encounters WHERE owner_id = ?',
    [_identity.ownerId],
  );
}

Future<MemoryAudio> _ownedAudio(
  ProviderContainer container,
  String encounterId,
) async {
  final repository = await container.read(memoryAudioRepositoryProvider.future);
  return repository
      .watchForEncounter(encounterId)
      .firstWhere((value) => value != null)
      .then((value) => value!);
}

Future<List<int>> _audioEvidence(
  ProviderContainer container,
  String storageKey,
) async {
  final store = await container.read(audioAssetStoreProvider.future);
  final source = await store.open(storageKey);
  return switch (source) {
    BytesAudioPlaybackSource(:final bytes) => bytes,
    FileAudioPlaybackSource(:final path) when path.isNotEmpty => path.codeUnits,
    _ => fail('The saved private audio asset is unavailable.'),
  };
}

Future<void> _expectPlayback(
  ProviderContainer container,
  WidgetTester tester,
  String audioId,
) async {
  final coordinator = await container.read(
    memoryAudioPlaybackCoordinatorProvider.future,
  );
  for (var attempt = 0; attempt < 40; attempt++) {
    final status = coordinator.state.status;
    if (coordinator.state.assetId == audioId &&
        (status == MemoryAudioPlaybackStatus.playing ||
            status == MemoryAudioPlaybackStatus.completed ||
            status == MemoryAudioPlaybackStatus.idle)) {
      return;
    }
    if (status == MemoryAudioPlaybackStatus.error) {
      fail(coordinator.state.error ?? 'Audio playback failed.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList();
  fail(
    'Audio playback did not start. '
    'asset=${coordinator.state.assetId}, '
    'status=${coordinator.state.status}, '
    'error=${coordinator.state.error}, '
    'route=${appRouter.routerDelegate.currentConfiguration.uri}, '
    'visible=$visibleText',
  );
}

Future<void> _closeApp(
  WidgetTester tester,
  ProviderContainer container,
  AppDatabase database,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final reminders = await container.read(
    prayerReminderCoordinatorProvider.future,
  );
  container.dispose();
  await tester.pump();
  await reminders.dispose();
  for (var turn = 0; turn < 10; turn++) {
    await Future<void>.delayed(Duration.zero);
    await tester.pump();
  }
  await database.powersync.get('SELECT 1 AS ready');
  await database.close();
}

Future<String> _testDatabasePath() async {
  if (kIsWeb) return _databaseName;
  final directory = await getApplicationSupportDirectory();
  return path.join(directory.path, _databaseName);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150 && finder.evaluate().isEmpty; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  expect(finder, findsAtLeastNWidgets(1));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: true);
  await tester.pump();
}

void _expectNoException(WidgetTester tester, String stage) {
  expect(tester.takeException(), isNull, reason: stage);
}
