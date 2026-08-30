import '../domain/today_guidance.dart';

abstract interface class TodayGuidanceRepository {
  Stream<TodayGuidanceSnapshot> watch(DateTime displayedLocalDate);
}
