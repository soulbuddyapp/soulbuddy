import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'spiritual_session_controller.dart';

final spiritualSessionControllerProvider = Provider<SpiritualSessionController>(
  (ref) {
    final controller = SpiritualSessionController();
    ref.onDispose(controller.dispose);
    return controller;
  },
);
