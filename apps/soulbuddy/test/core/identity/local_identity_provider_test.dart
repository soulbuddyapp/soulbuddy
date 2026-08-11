import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'persists one shared local identity using the established keys',
    () async {
      FlutterSecureStorage.setMockInitialValues({});

      final firstContainer = ProviderContainer();
      final first = await firstContainer.read(localIdentityProvider.future);
      firstContainer.dispose();

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      final second = await secondContainer.read(localIdentityProvider.future);

      expect(second.ownerId, first.ownerId);
      expect(second.deviceId, first.deviceId);

      const storage = FlutterSecureStorage();
      final stored = await storage.readAll();
      expect(stored, {
        'soulbuddy.local_owner_id': first.ownerId,
        'soulbuddy.device_id': first.deviceId,
      });
    },
  );
}
