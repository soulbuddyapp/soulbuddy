import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'spiritual_session_controller.dart';

final systemPlaybackAvailableProvider = Provider<bool>((ref) => false);
final systemAudioFocusProvider = Provider<Future<bool> Function(bool)?>(
  (ref) => null,
);

final spiritualSessionControllerProvider = Provider<SpiritualSessionController>(
  (ref) {
    final controller = SpiritualSessionController();
    ref.onDispose(controller.dispose);
    return controller;
  },
);
