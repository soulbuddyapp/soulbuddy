import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/data/person_prayer_audio_repository.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';

class FakeStore implements AudioAssetStore {
  final deleted = <String>[];
  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async => CommittedAudio(storageKey: 'audio/$assetId.m4a', byteSize: 100);
  @override
  Future<void> delete(String storageKey) async {
    deleted.add(storageKey);
  }

  @override
  Future<void> discardTemporary(String locator) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('saves person audio privately and keeps it referenced', () async {
    String? stored;
    final store = FakeStore();
    final repo = PersonPrayerAudioRepository(
      read: () async => stored,
      write: (value) async => stored = value,
      store: store,
      newId: () => 'take1',
    );
    await repo.save(
      'person1',
      RecordedAudioDraft(
        temporaryKey: 'tmp',
        mimeType: 'audio/mp4',
        duration: const Duration(seconds: 2),
        waveform: const [0.2],
      ),
    );
    expect((await repo.load('person1'))?.storageKey, 'audio/take1.m4a');
    expect(await repo.ownedStorageKeys(), {'audio/take1.m4a'});
  });
  test('failed index write keeps old recording and cleans new audio', () async {
    final store = FakeStore();
    final repo = PersonPrayerAudioRepository(
      read: () async =>
          '{"person1":{"storageKey":"audio/old.m4a","durationMs":2000}}',
      write: (_) async => throw StateError('failed'),
      store: store,
      newId: () => 'new',
    );
    await expectLater(
      repo.save(
        'person1',
        RecordedAudioDraft(
          temporaryKey: 'tmp',
          mimeType: 'audio/mp4',
          duration: const Duration(seconds: 2),
          waveform: const [0.2],
        ),
      ),
      throwsStateError,
    );
    expect(store.deleted, ['audio/new.m4a']);
  });
}
