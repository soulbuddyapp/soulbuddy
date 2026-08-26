import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'prayer_reminder_scheduler.dart';

const _prayedActionId = 'PRAYED';
const _snoozeActionId = 'SNOOZE_10';
const _dismissActionId = 'DISMISS';
const _darwinCategoryId = 'PRAYER_REMINDER';
const _darwinAltarCategoryId = 'ALTAR_REMINDER';

enum NativePrayerScheduleMode { inexactAllowWhileIdle }

class NativeNotificationActionData {
  const NativeNotificationActionData({
    required this.id,
    required this.label,
    required this.showsUserInterface,
  });

  final String id;
  final String label;
  final bool showsUserInterface;
}

class NativeNotificationRequest {
  const NativeNotificationRequest({
    required this.platformNotificationId,
    required this.scheduledAtUtc,
    required this.title,
    required this.body,
    required this.payload,
    required this.scheduleMode,
    required this.startsAudio,
    required this.actions,
    this.recurrence = ReminderNotificationRecurrence.once,
  });

  final int platformNotificationId;
  final DateTime scheduledAtUtc;
  final String title;
  final String body;
  final String payload;
  final NativePrayerScheduleMode scheduleMode;
  final bool startsAudio;
  final List<NativeNotificationActionData> actions;
  final ReminderNotificationRecurrence recurrence;
}

class NativeNotificationResponseData {
  const NativeNotificationResponseData({this.actionId, this.payload});

  final String? actionId;
  final String? payload;
}

class NativeImmediateNotificationRequest {
  const NativeImmediateNotificationRequest({
    required this.title,
    required this.body,
    required this.startsAudio,
    this.payload,
  });

  final String title;
  final String body;
  final bool startsAudio;
  final String? payload;
}

abstract interface class NativePrayerNotificationClient {
  Stream<NativeNotificationResponseData> get responses;

  Future<void> initialize();

  Future<bool> requestPermission();

  Future<NotificationPermissionStatus> permissionStatus();

  Future<void> showImmediate(NativeImmediateNotificationRequest request);

  Future<void> schedule(NativeNotificationRequest request);

  Future<void> cancel(int platformNotificationId);
}

class NativePrayerReminderScheduler implements PrayerReminderScheduler {
  NativePrayerReminderScheduler({
    required NativePrayerNotificationClient client,
  }) : _client = client;

  final NativePrayerNotificationClient _client;
  Stream<PrayerReminderResponse>? _responses;
  Future<void>? _initialization;

  @override
  bool get supportsSystemNotifications => true;

  @override
  Stream<PrayerReminderResponse> get responses =>
      _responses ??= _client.responses.map(_decodeResponse);

  @override
  Future<void> initialize() => _initialization ??= _client.initialize();

  @override
  Future<bool> requestPermission() => _client.requestPermission();

  @override
  Future<NotificationPermissionStatus> permissionStatus() =>
      _client.permissionStatus();

  @override
  Future<void> showTestReminder() => _client.showImmediate(
    const NativeImmediateNotificationRequest(
      title: 'Prayer reminder',
      body: 'Your reminders are ready on this device',
      startsAudio: false,
    ),
  );

  @override
  Future<void> schedule(PrayerScheduledNotification notification) {
    final altar = notification.kind == ReminderNotificationKind.altar;
    return _client.schedule(
      NativeNotificationRequest(
        platformNotificationId: notification.platformNotificationId,
        scheduledAtUtc: notification.scheduledAtUtc,
        title: altar ? 'At your Altar' : 'Prayer reminder',
        body: altar
            ? 'Time set aside to pray and remember'
            : 'Time set aside for prayer',
        payload: jsonEncode({
          'reminder_id': notification.reminderId,
          'occurrence_key': notification.occurrenceKey,
          'kind': notification.kind.name,
        }),
        scheduleMode: NativePrayerScheduleMode.inexactAllowWhileIdle,
        startsAudio: false,
        actions: altar
            ? const []
            : const [
                NativeNotificationActionData(
                  id: _prayedActionId,
                  label: 'I prayed this',
                  showsUserInterface: true,
                ),
                NativeNotificationActionData(
                  id: _snoozeActionId,
                  label: 'In 10 minutes',
                  showsUserInterface: true,
                ),
                NativeNotificationActionData(
                  id: _dismissActionId,
                  label: 'Dismiss',
                  showsUserInterface: true,
                ),
              ],
        recurrence: notification.recurrence,
      ),
    );
  }

  @override
  Future<void> cancel(int platformNotificationId) =>
      _client.cancel(platformNotificationId);

  PrayerReminderResponse _decodeResponse(
    NativeNotificationResponseData response,
  ) {
    final payload = response.payload;
    if (payload == null) {
      throw const FormatException('Missing prayer reminder payload.');
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic> ||
        (decoded.length != 2 && decoded.length != 3) ||
        !decoded.containsKey('reminder_id') ||
        !decoded.containsKey('occurrence_key') ||
        (decoded.length == 3 && !decoded.containsKey('kind'))) {
      throw const FormatException('Invalid prayer reminder payload.');
    }
    final reminderId = decoded['reminder_id'];
    final occurrenceKey = decoded['occurrence_key'];
    final kindWire = decoded['kind'] ?? ReminderNotificationKind.prayer.name;
    if (!_isSafeIdentifier(reminderId) || !_isSafeIdentifier(occurrenceKey)) {
      throw const FormatException('Invalid prayer reminder identifiers.');
    }

    final kind = ReminderNotificationKind.values
        .cast<ReminderNotificationKind?>()
        .firstWhere((value) => value?.name == kindWire, orElse: () => null);
    if (kind == null) {
      throw const FormatException('Invalid prayer reminder kind.');
    }

    return PrayerReminderResponse(
      reminderId: reminderId as String,
      occurrenceKey: occurrenceKey as String,
      kind: kind,
      action: switch (response.actionId) {
        null || '' => PrayerReminderAction.open,
        _prayedActionId => PrayerReminderAction.prayed,
        _snoozeActionId => PrayerReminderAction.snoozeTenMinutes,
        _dismissActionId => PrayerReminderAction.dismiss,
        _ => throw const FormatException('Unknown prayer reminder action.'),
      },
    );
  }

  bool _isSafeIdentifier(Object? value) =>
      value is String && value.isNotEmpty && value.length <= 160;
}

class FlutterLocalNotificationsPrayerClient
    implements NativePrayerNotificationClient {
  FlutterLocalNotificationsPrayerClient({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _responses =
      StreamController<NativeNotificationResponseData>.broadcast();

  @override
  Stream<NativeNotificationResponseData> get responses => _responses.stream;

  @override
  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));

    final initializationSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        notificationCategories: [
          DarwinNotificationCategory(
            _darwinCategoryId,
            actions: [
              DarwinNotificationAction.plain(
                _prayedActionId,
                'I prayed this',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                _snoozeActionId,
                'In 10 minutes',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                _dismissActionId,
                'Dismiss',
                options: {DarwinNotificationActionOption.foreground},
              ),
            ],
          ),
          DarwinNotificationCategory(_darwinAltarCategoryId),
        ],
      ),
    );
    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _emitResponse,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) {
        _emitResponse(response);
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          true;
    }
    return true;
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    if (Platform.isAndroid) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return (enabled ?? true)
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }
    if (Platform.isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return (permissions?.isEnabled ?? true)
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }
    return NotificationPermissionStatus.granted;
  }

  @override
  Future<void> showImmediate(NativeImmediateNotificationRequest request) {
    return _plugin.show(
      id: 2147483000,
      title: request.title,
      body: request.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_reminders',
          'Prayer reminders',
          channelDescription: 'Private reminders to pray',
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: request.payload,
    );
  }

  @override
  Future<void> schedule(NativeNotificationRequest request) async {
    final androidActions = request.actions
        .map(
          (action) => AndroidNotificationAction(
            action.id,
            action.label,
            showsUserInterface: action.showsUserInterface,
          ),
        )
        .toList(growable: false);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_reminders',
        'Prayer reminders',
        channelDescription: 'Private reminders to pray',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
        actions: androidActions,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: request.actions.isEmpty
            ? _darwinAltarCategoryId
            : _darwinCategoryId,
      ),
    );
    await _plugin.zonedSchedule(
      id: request.platformNotificationId,
      title: request.title,
      body: request.body,
      scheduledDate: timezone.TZDateTime.from(
        request.scheduledAtUtc,
        timezone.local,
      ),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (request.recurrence) {
        ReminderNotificationRecurrence.once => null,
        ReminderNotificationRecurrence.daily => DateTimeComponents.time,
        ReminderNotificationRecurrence.weekly =>
          DateTimeComponents.dayOfWeekAndTime,
      },
      payload: request.payload,
    );
  }

  @override
  Future<void> cancel(int platformNotificationId) =>
      _plugin.cancel(id: platformNotificationId);

  void _emitResponse(NotificationResponse response) {
    _responses.add(
      NativeNotificationResponseData(
        actionId: response.actionId,
        payload: response.payload,
      ),
    );
  }
}

PrayerReminderScheduler createPrayerReminderScheduler() =>
    NativePrayerReminderScheduler(
      client: FlutterLocalNotificationsPrayerClient(),
    );
