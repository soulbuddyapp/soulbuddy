import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'app/app.dart';
import 'core/notifications/push_registration.dart';
import 'core/playback/spiritual_session_controller.dart';
import 'core/playback/spiritual_session_providers.dart';
import 'core/playback/system_playback_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SpiritualSessionController? playbackController;
  Future<bool> Function(bool)? setPlaybackFocus;
  var systemPlaybackReady = false;
  if (!kIsWeb && Platform.isAndroid) {
    final controller = SpiritualSessionController();
    final handler = SystemPlaybackHandler(controller);
    try {
      await AudioService.init(
        builder: () => handler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'app.soulbuddy.soulbuddy.recordings',
          androidNotificationChannelName: 'Audio playback',
          androidNotificationOngoing: false,
        ),
      );
      final audioSession = await AudioSession.instance;
      await audioSession.configure(const AudioSessionConfiguration.speech());
      audioSession.interruptionEventStream.listen((event) {
        if (event.begin) {
          unawaited(controller.pause().catchError((Object _) {}));
        }
      });
      audioSession.becomingNoisyEventStream.listen((_) {
        unawaited(controller.pause().catchError((Object _) {}));
      });
      playbackController = controller;
      setPlaybackFocus = (active) => audioSession.setActive(active);
      systemPlaybackReady = true;
    } on Exception {
      handler.dispose();
      controller.dispose();
      debugPrint('System playback controls unavailable.');
    }
  }
  var pushReady = false;
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      pushReady = true;
    } on Exception {
      debugPrint('Firebase notification initialization failed.');
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        pushReadyProvider.overrideWithValue(pushReady),
        systemPlaybackAvailableProvider.overrideWithValue(systemPlaybackReady),
        systemAudioFocusProvider.overrideWithValue(setPlaybackFocus),
        if (playbackController != null)
          spiritualSessionControllerProvider.overrideWithValue(
            playbackController,
          ),
      ],
      child: const SoulBuddyApp(),
    ),
  );
}
