import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/storage/persistent_storage.dart';

void main() {
  test('reports granted and denied browser persistence outcomes', () async {
    expect(
      await requestPersistentStorage(request: () async => true),
      PersistentStorageOutcome.granted,
    );
    expect(
      await requestPersistentStorage(request: () async => false),
      PersistentStorageOutcome.denied,
    );
  });

  test('keeps storage failures recoverable', () async {
    expect(
      await requestPersistentStorage(
        request: () async => throw StateError('not supported'),
      ),
      PersistentStorageOutcome.unavailable,
    );
  });
}
