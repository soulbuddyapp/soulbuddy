class FormationProfile {
  const FormationProfile({
    required this.ready,
    required this.minutes,
    this.reminderHour,
    this.reminderMinute,
  });

  const FormationProfile.initial()
    : ready = false,
      minutes = 10,
      reminderHour = null,
      reminderMinute = null;

  final bool ready;
  final int minutes;
  final int? reminderHour;
  final int? reminderMinute;

  bool get hasReminder => reminderHour != null && reminderMinute != null;

  factory FormationProfile.fromJson(Map<dynamic, dynamic> json) =>
      FormationProfile(
        ready: json['ready'] == true,
        minutes: ((json['minutes'] as num?)?.toInt() ?? 10).clamp(5, 15),
        reminderHour: (json['reminderHour'] as num?)?.toInt(),
        reminderMinute: (json['reminderMinute'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
    'ready': ready,
    'minutes': minutes,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
  };
}
