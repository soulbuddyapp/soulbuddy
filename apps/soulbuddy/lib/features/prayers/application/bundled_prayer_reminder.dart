import 'dart:async';
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'prayer_reminder_scheduler.dart';

class BundledPrayerReminder {
  BundledPrayerReminder({
    required this.scheduler,
    required this.read,
    required this.write,
    required this.timezoneName,
    required this.clock,
    this.isEligible,
  });
  final PrayerReminderScheduler scheduler;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final Future<String> Function() timezoneName;
  final DateTime Function() clock;
  final Future<bool> Function(String)? isEligible;
  static const prefix = '0198a100-0000-7000-8000-00000000000';
  static int? numberFor(String id) {
    if (!id.startsWith(prefix) || id.length != prefix.length + 1) return null;
    final n = int.tryParse(id.substring(prefix.length));
    return n != null && n >= 1 && n <= 9 ? n : null;
  }

  final _pendingEvents = <String>[];
  late final StreamController<String> _events =
      StreamController<String>.broadcast(onListen: _flushEvents);
  Stream<String> get events => _events.stream;
  void _flushEvents() {
    for (final id in List<String>.of(_pendingEvents)) {
      _events.add(id);
    }
    _pendingEvents.clear();
  }

  void _emit(String id) {
    if (_events.hasListener) {
      _events.add(id);
    } else {
      _pendingEvents.add(id);
    }
  }

  StreamSubscription<PrayerReminderResponse>? _subscription;
  bool _ready = false;
  Future<void> _tail = Future.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  (int, int, bool) _decodeTime(Object? value) {
    if (value is! List ||
        (value.length != 2 && value.length != 3) ||
        value[0] is! int ||
        value[1] is! int ||
        value[0] < 0 ||
        value[0] > 23 ||
        value[1] < 0 ||
        value[1] > 59 ||
        (value.length == 3 && value[2] is! bool)) {
      throw const FormatException('Invalid prayer reminder');
    }
    return (
      value[0] as int,
      value[1] as int,
      value.length == 2 ? true : value[2] as bool,
    );
  }

  Future<void> start() async {
    _subscription = scheduler
        .responsesFor(ReminderNotificationKind.builtInPrayer)
        .where(
          (r) =>
              r.kind == ReminderNotificationKind.builtInPrayer &&
              r.action == PrayerReminderAction.open &&
              numberFor(r.reminderId) != null,
        )
        .listen((r) => _emit(r.reminderId));
    await scheduler.initialize();
    _ready = true;
    await reconcile();
  }

  Future<void> reconcile() => _serialize(() async {
    if (!_ready) return;
    if (await scheduler.permissionStatus() ==
        NotificationPermissionStatus.granted) {
      final saved = await _load();
      for (final entry in saved.entries) {
        if (numberFor(entry.key) == null) {
          throw const FormatException('Invalid prayer reminder');
        }
        final (hour, minute, audio) = _decodeTime(entry.value);
        if (isEligible != null && !await isEligible!(entry.key)) {
          await scheduler.cancel(-(0x40000000 + numberFor(entry.key)!));
          continue;
        }
        await _schedule(entry.key, hour, minute, audio);
      }
    }
  });

  Future<Map<String, dynamic>> _load() async {
    final raw = await read();
    if (raw == null) return {};
    final value = jsonDecode(raw);
    if (value is! Map) throw const FormatException('Invalid prayer reminders');
    return Map<String, dynamic>.from(value);
  }

  Future<(int, int)?> timeFor(String id) async {
    await _tail;
    final value = (await _load())[id];
    if (value == null) return null;
    final (hour, minute, _) = _decodeTime(value);
    return (hour, minute);
  }

  Future<bool> audioEnabledFor(String id) async {
    await _tail;
    final value = (await _load())[id];
    return value == null ? true : _decodeTime(value).$3;
  }

  Future<void> setDaily(
    String id,
    int hour,
    int minute, {
    bool? audioEnabled,
  }) => _serialize(() async {
    final n = numberFor(id);
    if (n == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid prayer reminder');
    }
    if (isEligible != null && !await isEligible!(id)) {
      throw StateError('prayer_audio_unavailable');
    }
    if (!await scheduler.requestPermission()) {
      throw StateError('notification_permission_denied');
    }
    final index = await _load();
    final previous = index[id];
    final prior = previous == null ? null : _decodeTime(previous);
    final enabled = audioEnabled ?? prior?.$3 ?? true;
    await _schedule(id, hour, minute, enabled);
    index[id] = [hour, minute, enabled];
    try {
      await write(jsonEncode(index));
    } catch (_) {
      try {
        if (prior != null) {
          await _schedule(id, prior.$1, prior.$2, prior.$3);
        } else {
          await scheduler.cancel(-(0x40000000 + n));
        }
      } catch (_) {}
      rethrow;
    }
  });
  Future<void> _schedule(
    String id,
    int hour,
    int minute,
    bool audioEnabled,
  ) async {
    final n = numberFor(id)!;
    final name = await timezoneName();
    final location = tz.getLocation(name);
    final now = tz.TZDateTime.from(clock(), location);
    var next = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    await scheduler.schedule(
      PrayerScheduledNotification(
        platformNotificationId: -(0x40000000 + n),
        reminderId: id,
        occurrenceKey: '$id@daily',
        scheduledAtUtc: next.toUtc(),
        kind: ReminderNotificationKind.builtInPrayer,
        recurrence: ReminderNotificationRecurrence.daily,
        timeZoneName: name,
        soundKey: audioEnabled
            ? 'builtin_prayer_${n.toString().padLeft(2, '0')}'
            : 'silent',
      ),
    );
  }

  Future<void> remove(String id) => _serialize(() async {
    final n = numberFor(id);
    if (n == null) throw ArgumentError('Invalid prayer');
    final index = await _load();
    final previous = index.remove(id);
    if (previous == null) return;
    final prior = _decodeTime(previous);
    await scheduler.cancel(-(0x40000000 + n));
    try {
      await write(jsonEncode(index));
    } catch (_) {
      try {
        await _schedule(id, prior.$1, prior.$2, prior.$3);
      } catch (_) {}
      rethrow;
    }
  });
  Future<void> close() async {
    _ready = false;
    await _tail;
    await _subscription?.cancel();
    await _events.close();
  }
}
