enum GoalMeditationFrequency { daily, weekly }

class GoalMeditationPlan {
  const GoalMeditationPlan({
    required this.goalId,
    required this.frequency,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    this.weekday = DateTime.monday,
  });

  final String goalId;
  final GoalMeditationFrequency frequency;
  final int weekday;
  final int hour;
  final int minute;
  final int durationMinutes;

  DateTime nextAfter(DateTime now) {
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (frequency == GoalMeditationFrequency.weekly) {
      candidate = DateTime(
        now.year,
        now.month,
        now.day + (weekday - now.weekday + 7) % 7,
        hour,
        minute,
      );
    }
    if (!candidate.isAfter(now)) {
      final days = frequency == GoalMeditationFrequency.daily ? 1 : 7;
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + days,
        hour,
        minute,
      );
    }
    return candidate;
  }

  Map<String, Object> toJson() => {
    'goalId': goalId,
    'frequency': frequency.name,
    'weekday': weekday,
    'hour': hour,
    'minute': minute,
    'durationMinutes': durationMinutes,
  };

  factory GoalMeditationPlan.fromJson(Map<String, dynamic> json) {
    final goalId = json['goalId'];
    final frequency = json['frequency'];
    final weekday = json['weekday'];
    final hour = json['hour'];
    final minute = json['minute'];
    final duration = json['durationMinutes'];
    if (goalId is! String ||
        goalId.isEmpty ||
        !['daily', 'weekly'].contains(frequency) ||
        weekday is! int ||
        weekday < 1 ||
        weekday > 7 ||
        hour is! int ||
        hour < 0 ||
        hour > 23 ||
        minute is! int ||
        minute < 0 ||
        minute > 59 ||
        duration is! int ||
        ![5, 10, 15, 20, 30].contains(duration)) {
      throw const FormatException('Invalid goal meditation plan');
    }
    return GoalMeditationPlan(
      goalId: goalId,
      frequency: GoalMeditationFrequency.values.byName(frequency as String),
      weekday: weekday,
      hour: hour,
      minute: minute,
      durationMinutes: duration,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GoalMeditationPlan &&
      other.goalId == goalId &&
      other.frequency == frequency &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute &&
      other.durationMinutes == durationMinutes;

  @override
  int get hashCode =>
      Object.hash(goalId, frequency, weekday, hour, minute, durationMinutes);
}

class GoalMeditationEntry {
  const GoalMeditationEntry({
    required this.id,
    required this.goalId,
    required this.createdAt,
    required this.text,
  });
  final String id;
  final String goalId;
  final DateTime createdAt;
  final String text;

  Map<String, Object> toJson() => {
    'id': id,
    'goalId': goalId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'text': text,
  };

  factory GoalMeditationEntry.fromJson(Map<String, dynamic> json) =>
      GoalMeditationEntry(
        id: json['id'] as String,
        goalId: json['goalId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        text: json['text'] as String,
      );
}
