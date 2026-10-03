import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/identity/account_profile_registry.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';

void main() {
  test('creates one active profile from the legacy local identity', () async {
    final storage = <String, String>{};
    final registry = AccountProfileRegistry(
      read: (key) async => storage[key],
      write: (key, value) async => storage[key] = value,
    );
    const identity = LocalIdentity(
      ownerId: '2d1b2ca3-7f06-49f9-b1f4-488a8f66d32f',
      deviceId: '88e274a0-6e7c-4b1a-b27d-e1dd143b9d81',
    );

    final active = await registry.loadOrCreate(identity);

    expect(active.ownerId, identity.ownerId);
    expect(active.deviceId, identity.deviceId);
    expect(active.databaseName, 'soulbuddy-${identity.ownerId}.db');
    expect(active.storagePrefix, 'soulbuddy.profile.${identity.ownerId}.');
    expect(storage[activeAccountProfileStorageKey], identity.ownerId);

    final saved = jsonDecode(storage[accountProfilesStorageKey]!) as Map;
    expect(saved['activeOwnerId'], identity.ownerId);
    expect(
      (saved['profiles'] as List).single['databaseName'],
      active.databaseName,
    );
  });

  test(
    'switches only to an existing profile and keeps its storage boundary',
    () async {
      final storage = <String, String>{};
      final registry = AccountProfileRegistry(
        read: (key) async => storage[key],
        write: (key, value) async => storage[key] = value,
      );
      const first = LocalIdentity(ownerId: 'owner-one', deviceId: 'device-one');
      const second = AccountProfile(
        ownerId: 'owner-two',
        deviceId: 'device-two',
        databaseName: 'soulbuddy-owner-two.db',
        storagePrefix: 'soulbuddy.profile.owner-two.',
      );

      await registry.loadOrCreate(first);
      await registry.add(second);
      await registry.activate(second.ownerId);

      expect((await registry.active()).ownerId, second.ownerId);
      expect(storage[activeAccountProfileStorageKey], second.ownerId);
      await expectLater(registry.activate('missing-owner'), throwsStateError);
    },
  );
}
