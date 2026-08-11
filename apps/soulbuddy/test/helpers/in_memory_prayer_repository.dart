import 'dart:async';

import 'package:soulbuddy/features/prayers/data/prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';

class InMemoryPrayerRepository implements PrayerRepository {
  InMemoryPrayerRepository({required List<LibraryPrayer> prayers})
    : _prayers = List.of(prayers);

  final List<LibraryPrayer> _prayers;
  final _changes = StreamController<void>.broadcast(sync: true);

  String? selectedPrayerId;
  bool? selectedIncludeAction;

  @override
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
  }) async* {
    yield _filtered(grounding: grounding, purpose: purpose);
    await for (final _ in _changes.stream) {
      yield _filtered(grounding: grounding, purpose: purpose);
    }
  }

  @override
  Stream<LibraryPrayer?> watchPrayer(String id) async* {
    yield _find(id);
    await for (final _ in _changes.stream) {
      yield _find(id);
    }
  }

  @override
  Future<void> setHelpful(String prayerId, {required bool value}) async {
    final index = _prayers.indexWhere((prayer) => prayer.id == prayerId);
    if (index == -1) return;
    final current = _prayers[index];
    _prayers[index] = LibraryPrayer(
      id: current.id,
      title: current.title,
      body: current.body,
      grounding: current.grounding,
      purpose: current.purpose,
      helpfulCount: current.helpfulCount,
      viewerMarkedHelpful: value,
      action: current.action,
    );
    _changes.add(null);
  }

  @override
  Future<void> selectForToday(
    String prayerId, {
    required bool includeAction,
  }) async {
    selectedPrayerId = prayerId;
    selectedIncludeAction = includeAction;
  }

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) => const Stream.empty();

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required bool value,
  }) async {}

  Future<void> close() => _changes.close();

  List<LibraryPrayer> _filtered({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
  }) {
    return _prayers
        .where(
          (prayer) =>
              (grounding == null || prayer.grounding == grounding) &&
              (purpose == null || prayer.purpose == purpose),
        )
        .toList(growable: false);
  }

  LibraryPrayer? _find(String id) {
    for (final prayer in _prayers) {
      if (prayer.id == id) return prayer;
    }
    return null;
  }
}
