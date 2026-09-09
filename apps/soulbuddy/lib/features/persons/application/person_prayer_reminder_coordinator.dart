import 'dart:async';

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../data/person_repository.dart';
import '../domain/prayer_person.dart';

class PersonPrayerReminderOpened {
  const PersonPrayerReminderOpened(this.personId);
  final String personId;
}

class PersonPrayerReminderCoordinator {
  PersonPrayerReminderCoordinator({
    required PersonRepository repository,
    required PrayerReminderScheduler scheduler,
    required Future<String> Function() timezoneName,
    Future<bool> Function()? requestExactTiming,
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _timezoneName = timezoneName,
       _requestExactTiming = requestExactTiming,
       _clock = clock ?? DateTime.now {
    timezone_data.initializeTimeZones();
    _events = StreamController<PersonPrayerReminderOpened>.broadcast(
      onListen: _flushPendingOpen,
    );
  }

  final PersonRepository _repository;
  final PrayerReminderScheduler _scheduler;
  final Future<String> Function() _timezoneName;
  final Future<bool> Function()? _requestExactTiming;
  final DateTime Function() _clock;
  late final StreamController<PersonPrayerReminderOpened> _events;
  String? _pendingOpenPersonId;
  final _scheduled = <String, Map<int, String>>{};
  StreamSubscription<List<PrayerPerson>>? _peopleSubscription;
  StreamSubscription<PrayerReminderResponse>? _responseSubscription;
  List<PrayerPerson> _people = const [];
  final _pendingResponses = <PrayerReminderResponse>[];
  Future<void> _serial = Future.value();
  bool _allowed = false;
  bool _exactSchedulingUnavailable = false;
  bool _peopleLoaded = false;

  Stream<PersonPrayerReminderOpened> get events => _events.stream;

  Future<void> start() async {
    _responseSubscription = _scheduler.responses
        .where((response) => response.kind == ReminderNotificationKind.person)
        .listen((response) {
          _pendingResponses.add(response);
          _enqueueInBackground(_drainResponses);
        });
    _peopleSubscription = _repository.watchForReminders().listen((people) {
      _people = people;
      _peopleLoaded = true;
      _enqueueInBackground(() async {
        await _drainResponses();
        await _reconcile();
      });
    });
    await _scheduler.initialize();
    _allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    await _enqueue(() async {
      await _drainResponses();
      await _reconcile();
    });
  }

  Future<bool> enable() async {
    _allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.requestPermission();
    if (_allowed) {
      final exactAllowed = await _requestExactTiming?.call();
      if (exactAllowed == true) _exactSchedulingUnavailable = false;
      await _enqueue(_reconcile);
    }
    return _allowed;
  }

  Future<void> _reconcile() async {
    if (!_allowed || !_scheduler.supportsSystemNotifications) return;
    final observed = <String>{};
    final fallbackTimezone = await _fallbackTimezone();
    final now = _clock().toUtc();
    for (final person in _people) {
      observed.add(person.id);
      final desired = person.archivedAt != null || person.localTime == null
          ? const <PrayerScheduledNotification>[]
          : _desired(person, fallbackTimezone, now);
      final desiredById = {
        for (final item in desired)
          item.platformNotificationId: _signature(item),
      };
      final previous = _scheduled[person.id];
      if (previous == null) {
        for (final id in _allIds(person.id)) {
          await _scheduler.cancel(id);
        }
      } else {
        for (final entry in previous.entries) {
          if (desiredById[entry.key] != entry.value) {
            await _scheduler.cancel(entry.key);
          }
        }
      }
      final scheduledNow = <int, String>{};
      for (final item in desired) {
        final signature = desiredById[item.platformNotificationId]!;
        if (previous?[item.platformNotificationId] != signature) {
          final actual = await _scheduleWithFallback(item);
          scheduledNow[item.platformNotificationId] = _signature(actual);
        } else {
          scheduledNow[item.platformNotificationId] = signature;
        }
      }
      _scheduled[person.id] = scheduledNow;
    }
    for (final personId in _scheduled.keys.toList(growable: false)) {
      if (observed.contains(personId)) continue;
      for (final id in _scheduled[personId]!.keys) {
        await _scheduler.cancel(id);
      }
      _scheduled.remove(personId);
    }
  }

  List<PrayerScheduledNotification> _desired(
    PrayerPerson person,
    String fallbackTimezone,
    DateTime nowUtc,
  ) {
    final zoneName = _validTimezone(person.timezone) ?? fallbackTimezone;
    final parts = person.localTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    if (person.cadence == PersonPrayerCadence.daily) {
      return [
        _notification(
          person,
          id: _baseId(person.id),
          at: _next(zoneName, hour, minute, null, nowUtc),
          recurrence: ReminderNotificationRecurrence.daily,
          zoneName: zoneName,
        ),
      ];
    }
    return [
      for (var weekday = 1; weekday <= 7; weekday++)
        if (person.weekdaysMask & (1 << (weekday - 1)) != 0)
          _notification(
            person,
            id: _weekdayId(person.id, weekday),
            at: _next(zoneName, hour, minute, weekday, nowUtc),
            recurrence: ReminderNotificationRecurrence.weekly,
            zoneName: zoneName,
          ),
    ];
  }

  PrayerScheduledNotification _notification(
    PrayerPerson person, {
    required int id,
    required DateTime at,
    required ReminderNotificationRecurrence recurrence,
    required String zoneName,
  }) => PrayerScheduledNotification(
    platformNotificationId: id,
    reminderId: person.id,
    occurrenceKey: '${person.id}@${at.toIso8601String()}',
    scheduledAtUtc: at,
    kind: ReminderNotificationKind.person,
    recurrence: recurrence,
    timeZoneName: zoneName,
    title: 'Remember ${person.name} in prayer',
    body: 'A moment to bring them before God',
    precision: _exactSchedulingUnavailable
        ? ReminderSchedulePrecision.ordinary
        : ReminderSchedulePrecision.exact,
  );

  Future<PrayerScheduledNotification> _scheduleWithFallback(
    PrayerScheduledNotification notification,
  ) async {
    try {
      await _scheduler.schedule(notification);
      return notification;
    } catch (_) {
      if (notification.precision != ReminderSchedulePrecision.exact) rethrow;
      _exactSchedulingUnavailable = true;
      final ordinary = PrayerScheduledNotification(
        platformNotificationId: notification.platformNotificationId,
        reminderId: notification.reminderId,
        occurrenceKey: notification.occurrenceKey,
        scheduledAtUtc: notification.scheduledAtUtc,
        kind: notification.kind,
        recurrence: notification.recurrence,
        timeZoneName: notification.timeZoneName,
        title: notification.title,
        body: notification.body,
        soundKey: notification.soundKey,
        precision: ReminderSchedulePrecision.ordinary,
      );
      await _scheduler.schedule(ordinary);
      return ordinary;
    }
  }

  DateTime _next(
    String zoneName,
    int hour,
    int minute,
    int? weekday,
    DateTime nowUtc,
  ) {
    final location = timezone.getLocation(zoneName);
    final localNow = timezone.TZDateTime.from(nowUtc, location);
    var days = weekday == null ? 0 : (weekday - localNow.weekday + 7) % 7;
    var candidate = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day + days,
      hour,
      minute,
    );
    if (!candidate.isAfter(localNow)) {
      days = weekday == null ? 1 : 7;
      candidate = timezone.TZDateTime(
        location,
        candidate.year,
        candidate.month,
        candidate.day + days,
        hour,
        minute,
      );
    }
    return candidate.toUtc();
  }

  Future<void> _handle(PrayerReminderResponse response) async {
    final person = _people.cast<PrayerPerson?>().firstWhere(
      (item) => item?.id == response.reminderId,
      orElse: () => null,
    );
    if (person == null || person.archivedAt != null) return;
    if (response.action == PrayerReminderAction.prayed) {
      await _repository.recordPrayer(person.id, localDate: _clock());
    } else if (response.action == PrayerReminderAction.open &&
        !_events.isClosed) {
      if (_events.hasListener) {
        _events.add(PersonPrayerReminderOpened(person.id));
      } else {
        _pendingOpenPersonId = person.id;
      }
    }
  }

  void _flushPendingOpen() {
    final personId = _pendingOpenPersonId;
    if (personId == null || _events.isClosed) return;
    _pendingOpenPersonId = null;
    scheduleMicrotask(() {
      if (!_events.isClosed) {
        _events.add(PersonPrayerReminderOpened(personId));
      }
    });
  }

  Future<void> _drainResponses() async {
    if (!_peopleLoaded || _pendingResponses.isEmpty) return;
    final responses = List<PrayerReminderResponse>.of(_pendingResponses);
    _pendingResponses.clear();
    for (final response in responses) {
      await _handle(response);
    }
  }

  int _legacyBaseId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  // Android notification IDs are shared by every reminder type in the app.
  // Keep Person reminders in a negative, dedicated range so a Person and a
  // Sacred Hour scheduled for the same time can never replace one another.
  int _baseId(String id) => -(0x10000000 | (_legacyBaseId(id) & 0x07ffffff));

  int _weekdayId(String id, int weekday) =>
      -(0x18000000 | (((_legacyBaseId(id) * 31) + weekday) & 0x07ffffff));

  int _legacyWeekdayId(String id, int weekday) =>
      ((_legacyBaseId(id) * 31) + weekday) & 0x7fffffff;

  Set<int> _allIds(String id) => {
    _baseId(id),
    for (var weekday = 1; weekday <= 7; weekday++) _weekdayId(id, weekday),
    // Remove schedules created before reminder IDs were namespaced.
    _legacyBaseId(id),
    for (var weekday = 1; weekday <= 7; weekday++)
      _legacyWeekdayId(id, weekday),
  };

  String _signature(PrayerScheduledNotification item) =>
      '${item.recurrence.name}:${item.timeZoneName}:${item.scheduledAtUtc.toIso8601String()}';

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _serial.then((_) => action());
    _serial = operation.catchError((_) {
      // One invalid schedule or platform failure must not poison every later
      // Person reminder reconciliation.
    });
    return operation;
  }

  void _enqueueInBackground(Future<void> Function() action) {
    unawaited(_enqueue(action).catchError((_) {}));
  }

  Future<String> _fallbackTimezone() async {
    try {
      return _validTimezone(await _timezoneName()) ?? 'UTC';
    } catch (_) {
      return 'UTC';
    }
  }

  String? _validTimezone(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    try {
      timezone.getLocation(name);
      return name;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _peopleSubscription?.cancel();
    await _responseSubscription?.cancel();
    await _events.close();
  }
}
