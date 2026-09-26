import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../application/commitment_reminder_coordinator.dart';
import 'commitment_providers.dart';

final commitmentReminderCoordinatorProvider =
    FutureProvider<CommitmentReminderCoordinator>((ref) async {
      final identity = await ref.watch(localIdentityProvider.future);
      final coordinator = CommitmentReminderCoordinator(
        repository: await ref.watch(commitmentRepositoryProvider.future),
        devices: await ref.watch(
          commitmentReminderDeviceRepositoryProvider.future,
        ),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
        ownerId: identity.ownerId,
        deviceId: identity.deviceId,
        timezoneName: ref.watch(prayerDeviceTimezoneProvider),
      );
      final lifecycle = _CommitmentReminderLifecycle(coordinator);
      WidgetsBinding.instance.addObserver(lifecycle);
      ref.onDispose(() {
        WidgetsBinding.instance.removeObserver(lifecycle);
        unawaited(coordinator.dispose());
      });
      await coordinator.start();
      return coordinator;
    });

class _CommitmentReminderLifecycle extends WidgetsBindingObserver {
  _CommitmentReminderLifecycle(this.coordinator);
  final CommitmentReminderCoordinator coordinator;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(coordinator.refresh());
    }
  }
}
