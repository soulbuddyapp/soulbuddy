import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../app/router.dart';
import '../config/app_config.dart';
import '../identity/local_identity_providers.dart';

final pushReadyProvider = Provider<bool>((ref) => false);

final pushRegistrationProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(pushReadyProvider)) return;
  await ref.watch(installationSessionBootstrapProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  final readToken = ref.watch(appSessionTokenReaderProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  final notifications = FlutterLocalNotificationsPlugin();
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        'soulbuddy_morning_v1',
        'Morning prayer',
        description: 'A daily invitation to pray at 5:30 a.m.',
        importance: Importance.high,
      ));

  Future<void> register(String? pushToken) async {
    final session = await readToken();
    if (session == null || session.isEmpty) return;
    final base = Uri.tryParse(AppConfig.apiBaseUrl);
    if (base == null || !base.hasScheme) return;
    try {
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      await client.post(
        base.resolve('/api/installations/push'),
        headers: {
          'authorization': 'Bearer $session',
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'device_id': identity.deviceId,
          'push_token': pushToken,
          'time_zone': zone,
        }),
      ).timeout(const Duration(seconds: 15));
    } on Exception {
      // Retry on app resume or token refresh when the network returns.
    }
  }

  Future<void> registerCurrent() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      await register(allowed ? await FirebaseMessaging.instance.getToken() : null);
    } on Exception {
      // Notification permission and Google Play services can be unavailable.
    }
  }

  await registerCurrent();
  final tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    unawaited(register(token));
  });
  final openSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
    if (message.data['kind'] == 'morning') appRouter.go('/today');
  });
  final foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
    if (message.data['kind'] != 'morning') return;
    unawaited(notifications.show(
      id: 530,
      title: message.notification?.title ?? 'Begin with God',
      body: message.notification?.body ?? 'A new day to pray, listen, and plant something good.',
      notificationDetails: const NotificationDetails(android: AndroidNotificationDetails(
        'soulbuddy_morning_v1',
        'Morning prayer',
        channelDescription: 'A daily invitation to pray at 5:30 a.m.',
        importance: Importance.high,
        priority: Priority.high,
      )),
    ));
  });
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage?.data['kind'] == 'morning') {
      WidgetsBinding.instance.addPostFrameCallback((_) => appRouter.go('/today'));
    }
  } on Exception {
    // Token registration and later notifications remain active.
  }
  final lifecycle = AppLifecycleListener(onResume: () => unawaited(registerCurrent()));
  ref.onDispose(() {
    unawaited(tokenSubscription.cancel());
    unawaited(openSubscription.cancel());
    unawaited(foregroundSubscription.cancel());
    lifecycle.dispose();
  });
});
