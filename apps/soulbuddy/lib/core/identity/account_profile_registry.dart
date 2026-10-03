import 'dart:convert';

import 'local_identity.dart';

const accountProfilesStorageKey = 'soulbuddy.account_profiles.v1';
const activeAccountProfileStorageKey = 'soulbuddy.active_profile.v1';

class AccountProfile {
  const AccountProfile({
    required this.ownerId,
    required this.deviceId,
    required this.databaseName,
    required this.storagePrefix,
  });

  factory AccountProfile.fromIdentity(LocalIdentity identity) => AccountProfile(
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
    databaseName: 'soulbuddy-${identity.ownerId}.db',
    storagePrefix: 'soulbuddy.profile.${identity.ownerId}.',
  );

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    ownerId: json['ownerId'] as String,
    deviceId: json['deviceId'] as String,
    databaseName: json['databaseName'] as String,
    storagePrefix: json['storagePrefix'] as String,
  );

  final String ownerId;
  final String deviceId;
  final String databaseName;
  final String storagePrefix;

  Map<String, String> toJson() => {
    'ownerId': ownerId,
    'deviceId': deviceId,
    'databaseName': databaseName,
    'storagePrefix': storagePrefix,
  };
}

class AccountProfileRegistry {
  AccountProfileRegistry({required this.read, required this.write});

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;

  Future<AccountProfile> loadOrCreate(LocalIdentity identity) async {
    final stored = await _load();
    if (stored == null) {
      final profile = AccountProfile.fromIdentity(identity);
      await _save(activeOwnerId: profile.ownerId, profiles: [profile]);
      return profile;
    }

    final active = stored.profiles
        .where((profile) => profile.ownerId == stored.activeOwnerId)
        .firstOrNull;
    if (active != null) return active;

    final profile = AccountProfile.fromIdentity(identity);
    final profiles = [
      ...stored.profiles.where((item) => item.ownerId != profile.ownerId),
      profile,
    ];
    await _save(activeOwnerId: profile.ownerId, profiles: profiles);
    return profile;
  }

  Future<void> add(AccountProfile profile) async {
    final stored = await _load();
    final profiles = [
      ...?stored?.profiles.where((item) => item.ownerId != profile.ownerId),
      profile,
    ];
    await _save(
      activeOwnerId: stored?.activeOwnerId ?? profile.ownerId,
      profiles: profiles,
    );
  }

  Future<AccountProfile> active() async {
    final stored = await _load();
    if (stored == null) throw StateError('No account profile is active.');
    return stored.profiles.firstWhere(
      (profile) => profile.ownerId == stored.activeOwnerId,
      orElse: () => throw StateError('No account profile is active.'),
    );
  }

  Future<void> activate(String ownerId) async {
    final stored = await _load();
    if (stored == null ||
        !stored.profiles.any((item) => item.ownerId == ownerId)) {
      throw StateError('Unknown account profile.');
    }
    await _save(activeOwnerId: ownerId, profiles: stored.profiles);
  }

  Future<_Profiles?> _load() async {
    final raw = await read(accountProfilesStorageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['activeOwnerId'] is! String ||
          decoded['profiles'] is! List) {
        return null;
      }
      final profiles = (decoded['profiles'] as List)
          .whereType<Map>()
          .map(
            (item) => AccountProfile.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      return _Profiles(
        activeOwnerId: decoded['activeOwnerId'] as String,
        profiles: profiles,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> _save({
    required String activeOwnerId,
    required List<AccountProfile> profiles,
  }) async {
    await write(
      accountProfilesStorageKey,
      jsonEncode({
        'version': 1,
        'activeOwnerId': activeOwnerId,
        'profiles': profiles.map((item) => item.toJson()).toList(),
      }),
    );
    await write(activeAccountProfileStorageKey, activeOwnerId);
  }
}

class _Profiles {
  const _Profiles({required this.activeOwnerId, required this.profiles});

  final String activeOwnerId;
  final List<AccountProfile> profiles;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
