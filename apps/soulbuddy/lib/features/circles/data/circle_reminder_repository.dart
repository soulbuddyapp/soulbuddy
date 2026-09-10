import 'dart:async';
import 'dart:convert';

import '../domain/circle_reminder.dart';

class CircleReminderRepository {
  CircleReminderRepository({required this.read, required this.write});

  static const storageKey = 'circle.reminders.v1';

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final _changes = StreamController<List<CircleReminder>>.broadcast();
  Future<void> _pending = Future.value();
  List<CircleReminder>? _current;

  Future<List<CircleReminder>> load() async {
    await _pending;
    return List.unmodifiable(await _load());
  }

  Stream<List<CircleReminder>> watch() async* {
    yield await load();
    yield* _changes.stream;
  }

  Future<void> save(CircleReminder reminder) => _change(
    (current) => [
      for (final value in current)
        if (value.circleId != reminder.circleId) value,
      reminder,
    ],
  );

  Future<void> remove(String circleId) => _change(
    (current) => [
      for (final value in current)
        if (value.circleId != circleId) value,
    ],
  );

  Future<void> _change(
    List<CircleReminder> Function(List<CircleReminder> current) transform,
  ) {
    final operation = _pending.then((_) async {
      final next = List<CircleReminder>.unmodifiable(transform(await _load()));
      await write(
        storageKey,
        jsonEncode([for (final reminder in next) reminder.toJson()]),
      );
      _current = next;
      _changes.add(next);
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<List<CircleReminder>> _load() async {
    final cached = _current;
    if (cached != null) return cached;
    final raw = await read(storageKey);
    if (raw == null) return _current = const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _current = const [];
      final reminders = <CircleReminder>[];
      final ids = <String>{};
      for (final value in decoded) {
        if (value is! Map) return _current = const [];
        final reminder = CircleReminder.fromJson(
          value.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (!ids.add(reminder.circleId)) return _current = const [];
        reminders.add(reminder);
      }
      return _current = List.unmodifiable(reminders);
    } on FormatException {
      return _current = const [];
    } on ArgumentError {
      return _current = const [];
    }
  }

  Future<void> dispose() => _changes.close();
}
