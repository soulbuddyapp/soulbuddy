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
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _timezoneName = timezoneName,
       _clock = clock ?? DateTime.now {
    timezone_data.initializeTimeZones();
  }

  final PersonRepository _repository;
  final PrayerReminderScheduler _scheduler;
  final Future<String> Function() _timezoneName;
  final DateTime Function() _clock;
  final _events = StreamController<PersonPrayerReminderOpened>.broadcast();
  final _scheduled = <String, Map<int, String>>{};
  StreamSubscription<List<PrayerPerson>>? _peopleSubscription;
  StreamSubscription<PrayerReminderResponse>? _responseSubscription;
  List<PrayerPerson> _people = const [];
  Future<void> _serial = Future.value();
  bool _allowed = false;

  Stream<PersonPrayerReminderOpened> get events => _events.stream;

  Future<void> start() async {
    await _scheduler.initialize();
    _allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    _responseSubscription = _scheduler.responses
        .where((response) => response.kind == ReminderNotificationKind.person)
        .listen((response) => _enqueue(() => _handle(response)));
    _peopleSubscription = _repository.watchForReminders().listen((people) {
      _people = people;
      _enqueue(_reconcile);
    });
    await _reconcile();
  }

  Future<bool> enable() async {
    _allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.requestPermission();
    if (_allowed) await _enqueue(_reconcile);
    return _allowed;
  }

  Future<void> _reconcile() async {
    if (!_allowed || !_scheduler.supportsSystemNotifications) return;
    final observed = <String>{};
    final fallbackTimezone = await _timezoneName();
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
      for (final item in desired) {
        final signature = desiredById[item.platformNotificationId]!;
        if (previous?[item.platformNotificationId] != signature) {
          await _scheduler.schedule(item);
        }
      }
      _scheduled[person.id] = desiredById;
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
    final zoneName = person.timezone ?? fallbackTimezone;
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
  );

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
      _events.add(PersonPrayerReminderOpened(person.id));
    }
  }

  int _baseId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  int _weekdayId(String id, int weekday) =>
      ((_baseId(id) * 31) + weekday) & 0x7fffffff;

  Set<int> _allIds(String id) => {
    _baseId(id),
    for (var weekday = 1; weekday <= 7; weekday++) _weekdayId(id, weekday),
  };

  String _signature(PrayerScheduledNotification item) =>
      '${item.recurrence.name}:${item.timeZoneName}:${item.scheduledAtUtc.toIso8601String()}';

  Future<void> _enqueue(Future<void> Function() action) {
    _serial = _serial.then((_) => action());
    return _serial;
  }

  Future<void> dispose() async {
    await _peopleSubscription?.cancel();
    await _responseSubscription?.cancel();
    await _events.close();
  }
}
