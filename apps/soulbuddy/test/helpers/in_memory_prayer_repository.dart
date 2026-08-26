import 'dart:async';

import 'package:soulbuddy/features/prayers/data/prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';

class InMemoryPrayerRepository implements PrayerRepository {
  InMemoryPrayerRepository({
    required List<LibraryPrayer> prayers,
    TodayPrayer? todayPrayer,
  }) : _prayers = List.of(prayers),
       _todayPrayer = todayPrayer;

  final List<LibraryPrayer> _prayers;
  final _changes = StreamController<void>.broadcast(sync: true);
  TodayPrayer? _todayPrayer;

  String? selectedPrayerId;
  bool? selectedIncludeAction;
  DateTime? watchedTodayDate;
  DateTime? completedTodayDate;
  String? completedTodayPrayerId;
  bool? completedTodayValue;

  @override
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
  }) async* {
    yield _filtered(
      grounding: grounding,
      purpose: purpose,
      languagePreference: languagePreference,
    );
    await for (final _ in _changes.stream) {
      yield _filtered(
        grounding: grounding,
        purpose: purpose,
        languagePreference: languagePreference,
      );
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
      languageStyle: current.languageStyle,
      action: current.action,
    );
    _changes.add(null);
  }

  @override
  Future<void> selectForToday(
    PrayerReference prayer, {
    required bool includeAction,
  }) async {
    selectedPrayerId = prayer.id;
    selectedIncludeAction = includeAction;
  }

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) async* {
    watchedTodayDate = localDate;
    yield _todayFor(localDate);
    await for (final _ in _changes.stream) {
      yield _todayFor(localDate);
    }
  }

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required PrayerReference expectedPrayer,
    required bool value,
  }) async {
    completedTodayDate = localDate;
    completedTodayPrayerId = expectedPrayer.id;
    completedTodayValue = value;
    final current = _todayFor(localDate);
    if (current == null || current.prayer.reference != expectedPrayer) return;
    _todayPrayer = TodayPrayer(
      prayer: current.prayer,
      localDate: current.localDate,
      includeAction: current.includeAction,
      actionCompleted: value,
    );
    _changes.add(null);
  }

  Future<void> close() => _changes.close();

  List<LibraryPrayer> _filtered({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
  }) {
    final prayers = _prayers
        .where(
          (prayer) =>
              (grounding == null || prayer.grounding == grounding) &&
              (purpose == null || prayer.purpose == purpose),
        )
        .toList();
    if (languagePreference != null) {
      prayers.sort(
        (left, right) => languagePreference
            .rankOf(left.languageStyle)
            .compareTo(languagePreference.rankOf(right.languageStyle)),
      );
    }
    return List.unmodifiable(prayers);
  }

  LibraryPrayer? _find(String id) {
    for (final prayer in _prayers) {
      if (prayer.id == id) return prayer;
    }
    return null;
  }

  TodayPrayer? _todayFor(DateTime localDate) {
    final today = _todayPrayer;
    if (today == null ||
        today.localDate.year != localDate.year ||
        today.localDate.month != localDate.month ||
        today.localDate.day != localDate.day) {
      return null;
    }
    return today;
  }
}

class DelayedSelectionPrayerRepository extends InMemoryPrayerRepository {
  DelayedSelectionPrayerRepository({required super.prayers});

  final selectionStarted = Completer<void>();
  final _allowSelection = Completer<void>();

  @override
  Future<void> selectForToday(
    PrayerReference prayer, {
    required bool includeAction,
  }) async {
    if (!selectionStarted.isCompleted) selectionStarted.complete();
    await _allowSelection.future;
    await super.selectForToday(prayer, includeAction: includeAction);
  }

  void completeSelection() {
    if (!_allowSelection.isCompleted) _allowSelection.complete();
  }
}
