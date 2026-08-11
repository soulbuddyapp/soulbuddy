enum PrayerGrounding {
  generalChristian('general_christian'),
  catholic('catholic');

  const PrayerGrounding(this.wireValue);

  final String wireValue;

  static PrayerGrounding fromWire(String value) {
    return values.firstWhere(
      (grounding) => grounding.wireValue == value,
      orElse: () => throw FormatException('Unknown prayer grounding: $value'),
    );
  }
}

enum PrayerPurpose {
  daily('daily'),
  gratitude('gratitude'),
  guidance('guidance'),
  family('family'),
  healing('healing'),
  work('work'),
  forgiveness('forgiveness'),
  difficultTime('difficult_time');

  const PrayerPurpose(this.wireValue);

  final String wireValue;

  static PrayerPurpose fromWire(String value) {
    return values.firstWhere(
      (purpose) => purpose.wireValue == value,
      orElse: () => throw FormatException('Unknown prayer purpose: $value'),
    );
  }
}

class LibraryPrayer {
  const LibraryPrayer({
    required this.id,
    required this.title,
    required this.body,
    required this.grounding,
    required this.purpose,
    required this.helpfulCount,
    required this.viewerMarkedHelpful,
    this.action,
  });

  final String id;
  final String title;
  final String body;
  final PrayerGrounding grounding;
  final PrayerPurpose purpose;
  final int helpfulCount;
  final bool viewerMarkedHelpful;
  final String? action;
}
