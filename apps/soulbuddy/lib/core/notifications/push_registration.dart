import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../app/router.dart';
import '../config/app_config.dart';
import '../identity/local_identity_providers.dart';
import '../identity/installation_session.dart';
import '../../features/prayers/providers/prayer_practice_providers.dart';
import 'push_registration_sync.dart';

final pushReadyProvider = Provider<bool>((ref) => false);

/// The in-app route a notice opens, or null when it opens nothing.
///
/// A route is honoured only when the server sent it and it points at a path
/// this app actually serves, so a stale or unknown value cannot strand someone
/// on a blank screen.
String? notificationRoute(Map<String, dynamic>? data) {
  final kind = data?['kind'];
  if (kind == 'morning') return '/today';
  if (kind != 'weekly_prayer') return null;

  final slug = data?['route'];
  if (slug is! String) return null;

  return weeklyPrayerReleaseRoute(slug);
}

/// Builds the release route from a server-supplied route value, accepting only
/// the release path this app serves.
String? weeklyPrayerReleaseRoute(String route) {
  final uri = Uri.tryParse(route);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.query.isNotEmpty) {
    return null;
  }
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.length != 3 ||
      segments[0] != 'prayers' ||
      segments[1] != 'releases') {
    return null;
  }
  final slug = segments[2];
  if (slug.isEmpty || slug.contains('/')) return null;

  return '/prayers/releases/$slug';
}

final pushRegistrationProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(pushReadyProvider)) return;
  await ref.read(installationSessionBootstrapProvider.future);
  if (!ref.mounted) return;
  final identity = await ref.watch(localIdentityProvider.future);
  if (!ref.mounted) return;
  final readToken = ref.watch(appSessionTokenReaderProvider);
  final storage = ref.watch(secureStorageProvider);
  final scheduler = ref.watch(prayerReminderSchedulerProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  final base = Uri.tryParse(AppConfig.apiBaseUrl);
  if (base == null || !base.hasScheme) return;
  final messaging = FirebaseMessaging.instance;
  var permissionRequested = false;
  final bootstrap = InstallationSessionBootstrap(
    apiBaseUri: base,
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
    client: client,
  );
  final sync = PushRegistrationSync(
    baseUri: base,
    deviceId: identity.deviceId,
    client: client,
    readPushToken: messaging.getToken,
    readSession: readToken,
    refreshSession: () => bootstrap.ensure(identity),
    readTimeZone: () async =>
        (await FlutterTimezone.getLocalTimezone()).identifier,
    readPermission: () async {
      final settings = permissionRequested
          ? await messaging.getNotificationSettings()
          : await messaging.requestPermission();
      permissionRequested = true;
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.allowed,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.undetermined,
      };
    },
  );
  ref.onDispose(sync.dispose);
  final lifecycle = AppLifecycleListener(
    onResume: sync.resume,
    onPause: sync.pause,
  );
  ref.onDispose(lifecycle.dispose);
  // Listen before fetching the current token: an SDK refresh can happen during
  // startup, permission prompts, or a slow registration request.
  final tokenSubscription = messaging.onTokenRefresh.listen((_) {
    unawaited(sync.synchronize());
  });
  ref.onDispose(() => unawaited(tokenSubscription.cancel()));
  final notifications = FlutterLocalNotificationsPlugin();
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'soulbuddy_morning_v1',
          'Morning prayer',
          description: 'A daily invitation to pray at 5:30 a.m.',
          importance: Importance.high,
        ),
      );

  if (!ref.mounted) return;
  final openSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
    message,
  ) {
    final route = notificationRoute(message.data);
    if (route != null) appRouter.go(route);
  });
  final foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
    if (message.data['kind'] != 'morning') return;
    unawaited(
      () async {
        await scheduler.initialize();
        if (!ref.mounted) return;
        await notifications.show(
          id: 530,
          title: message.notification?.title ?? 'Begin with God',
          body:
              message.notification?.body ??
              'A new day to pray, listen, and plant something good.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'soulbuddy_morning_v1',
              'Morning prayer',
              channelDescription: 'A daily invitation to pray at 5:30 a.m.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }().catchError((Object error) {
        debugPrint(
          'Morning notification could not be displayed (${error.runtimeType}).',
        );
      }),
    );
  });
  ref.onDispose(() {
    unawaited(openSubscription.cancel());
    unawaited(foregroundSubscription.cancel());
  });
  await sync.synchronize();
  if (!ref.mounted) return;
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    final initialRoute = notificationRoute(initialMessage?.data);
    if (initialRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => appRouter.go(initialRoute),
      );
    }
  } on Exception {
    // Token registration and later notifications remain active.
  }
});
