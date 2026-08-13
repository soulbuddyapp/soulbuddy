import 'library_prayer.dart';

class TodayPrayer {
  const TodayPrayer({
    required this.prayer,
    required this.localDate,
    required this.includeAction,
    required this.actionCompleted,
    this.prayerRevisionId,
  });

  final PrayerDisplay prayer;
  final DateTime localDate;
  final bool includeAction;
  final bool actionCompleted;
  final String? prayerRevisionId;
}
