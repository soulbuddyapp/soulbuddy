import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'app/app.dart';
import 'core/notifications/push_registration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var pushReady = false;
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      pushReady = true;
    } on Exception {
      debugPrint('Firebase notification initialization failed.');
    }
  }
  runApp(ProviderScope(
    overrides: [pushReadyProvider.overrideWithValue(pushReady)],
    child: const SoulBuddyApp(),
  ));
}
