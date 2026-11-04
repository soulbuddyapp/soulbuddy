import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/powersync_personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/data/powersync_recorded_personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/data/powersync_voice_tablet_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store_io.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recorded-prayer-');
  });

  tearDown(() => directory.delete(recursive: true));

  test('recorded prayer reopens without invented words', () async {
    final path = '${directory.path}/prayers.db';
    var database = await openTestDatabase(path);
    final assets = IoAudioAssetStore(
      applicationSupportDirectory: Directory('${directory.path}/support'),
      temporaryDirectory: Directory('${directory.path}/temporary'),
    );
    final temporary = await assets.allocateTemporary(
      takeId: 'prayer-take',
      extension: 'm4a',
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await File(temporary.locator).writeAsBytes(bytes);
    final repository = PowerSyncRecordedPersonalPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      assetStore: assets,
    );
    final saved = await repository.create(
      title: 'For my family',
      purpose: PrayerPurpose.family,
      audio: _draft(temporary.locator),
    );
    expect(saved.body, isEmpty);
    expect(saved.contentFormat, PersonalPrayerContentFormat.audio);
    expect(await File(temporary.locator).exists(), isFalse);
    for (final table in [
      'personal_prayers',
      'personal_prayer_revisions',
      'voice_tablets',
      'voice_tablet_audio_assets',
    ]) {
      expect(
        await database.powersync.getAll('SELECT id FROM $table'),
        hasLength(1),
      );
    }
    await database.close();
    database = await openTestDatabase(path);
    addTearDown(database.close);
    final reopened = await PowerSyncPersonalPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    ).watch(saved.id).first;
    expect(reopened?.isAudio, isTrue);
    expect(reopened?.body, isEmpty);
    final source = VoiceTabletSource.personal(
      prayerId: saved.id,
      revisionId: saved.currentRevisionId,
    );
    final tablet = await PowerSyncVoiceTabletRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    ).watchForSource(source).first;
    expect(tablet?.fullAudio, isNotNull);
    final playback = await assets.open(tablet!.fullAudio!.storageKey);
    expect(playback, isA<FileAudioPlaybackSource>());
    expect(
      await File((playback as FileAudioPlaybackSource).path).readAsBytes(),
      bytes,
    );
    final otherOwner = await PowerSyncVoiceTabletRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      deviceId: 'device-1',
    ).watchForSource(source).first;
    expect(otherOwner, isNull);
  });

  test('failed asset import creates no prayer or recording metadata', () async {
    final database = await openTestDatabase('${directory.path}/import.db');
    addTearDown(database.close);
    final assets = _AssetStore()..failCommit = true;
    final repository = PowerSyncRecordedPersonalPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      assetStore: assets,
    );
    await expectLater(
      repository.create(title: 'My prayer', audio: _draft('take')),
      throwsStateError,
    );
    for (final table in [
      'personal_prayers',
      'personal_prayer_revisions',
      'voice_tablets',
      'voice_tablet_audio_assets',
    ]) {
      expect(await database.powersync.getAll('SELECT id FROM $table'), isEmpty);
    }
    expect(assets.discarded, isEmpty);
  });

  test('database failure keeps the take and removes the copy', () async {
    final database = await openTestDatabase('${directory.path}/failure.db');
    final assets = _AssetStore();
    final repository = PowerSyncRecordedPersonalPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      assetStore: assets,
    );
    await database.close();
    await expectLater(
      repository.create(title: 'My prayer', audio: _draft('retry-take')),
      throwsA(anything),
    );
    expect(assets.committed, hasLength(1));
    expect(assets.deleted, assets.committed);
    expect(assets.discarded, isEmpty);
  });

  test('cleanup failure does not fail a successful save', () async {
    final database = await openTestDatabase('${directory.path}/cleanup.db');
    addTearDown(database.close);
    final assets = _AssetStore()..failDiscard = true;
    final repository = PowerSyncRecordedPersonalPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      assetStore: assets,
    );
    final saved = await repository.create(
      title: 'My prayer',
      audio: _draft('take'),
    );
    expect(saved.isAudio, isTrue);
    expect(assets.deleted, isEmpty);
    expect(
      await database.powersync.getAll('SELECT id FROM personal_prayers'),
      hasLength(1),
    );
  });
}

RecordedAudioDraft _draft(String locator) => RecordedAudioDraft(
  temporaryKey: locator,
  mimeType: 'audio/mp4',
  duration: const Duration(seconds: 8),
  waveform: [0.1, 0.8, 0.3],
);

class _AssetStore implements AudioAssetStore {
  bool failCommit = false;
  bool failDiscard = false;
  final committed = <String>[];
  final deleted = <String>[];
  final discarded = <String>[];

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async {
    if (failCommit) throw StateError('storage unavailable');
    final key = 'audio/$assetId.m4a';
    committed.add(key);
    return CommittedAudio(storageKey: key, byteSize: 4);
  }

  @override
  Future<void> delete(String storageKey) async => deleted.add(storageKey);

  @override
  Future<void> discardTemporary(String locator) async {
    if (failDiscard) throw StateError('cleanup unavailable');
    discarded.add(locator);
  }

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) async => TemporaryAudio(key: takeId, locator: '$takeId.$extension');

  @override
  Future<AudioPlaybackSource?> open(String storageKey) async => null;

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) async {}
}
