import 'dart:convert';
import '../../record/audio/data/audio_asset_store.dart';
import '../../record/audio/domain/memory_audio.dart';

class PersonPrayerAudio {
  const PersonPrayerAudio({required this.storageKey, required this.duration});
  final String storageKey;
  final Duration duration;
}

class PersonPrayerAudioRepository {
  PersonPrayerAudioRepository({
    required this.read,
    required this.write,
    required this.store,
    required this.newId,
  });
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final AudioAssetStore store;
  final String Function() newId;
  Future<void> _tail = Future.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<Map<String, dynamic>> _index() async {
    final raw = await read();
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Invalid recording index');
    return Map<String, dynamic>.from(decoded);
  }

  Future<PersonPrayerAudio?> load(String personId) async {
    await _tail;
    final value = (await _index())[personId];
    if (value == null) return null;
    if (value is! Map ||
        value['storageKey'] is! String ||
        value['durationMs'] is! int) {
      throw const FormatException('Invalid recording');
    }
    return PersonPrayerAudio(
      storageKey: value['storageKey'] as String,
      duration: Duration(milliseconds: value['durationMs'] as int),
    );
  }

  Future<Set<String>> ownedStorageKeys() async {
    await _tail;
    final values = (await _index()).values;
    return values.map((entry) {
      if (entry is! Map || entry['storageKey'] is! String) {
        throw const FormatException('Invalid recording');
      }
      return entry['storageKey'] as String;
    }).toSet();
  }

  Future<void> save(String personId, RecordedAudioDraft draft) =>
      _serialize(() async {
        final index = await _index();
        final old = index[personId];
        final committed = await store.commitTemporary(
          TemporaryAudio(key: draft.temporaryKey, locator: draft.temporaryKey),
          assetId: newId(),
          mimeType: draft.mimeType,
        );
        index[personId] = {
          'storageKey': committed.storageKey,
          'durationMs': draft.duration.inMilliseconds,
        };
        try {
          await write(jsonEncode(index));
        } catch (_) {
          try {
            await store.delete(committed.storageKey);
          } catch (_) {}
          rethrow;
        }
        try {
          await store.discardTemporary(draft.temporaryKey);
        } catch (_) {}
        if (old is Map && old['storageKey'] is String) {
          try {
            await store.delete(old['storageKey'] as String);
          } catch (_) {}
        }
      });
  Future<void> remove(String personId) => _serialize(() async {
    final index = await _index();
    final old = index.remove(personId);
    if (old == null) return;
    await write(jsonEncode(index));
    if (old is Map && old['storageKey'] is String) {
      await store.delete(old['storageKey'] as String);
    }
  });
}
