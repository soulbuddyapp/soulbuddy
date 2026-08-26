import 'prayer_reference.dart';
import 'prayer_language.dart';

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

abstract interface class PrayerDisplay {
  PrayerReference get reference;
  String get id;
  String get title;
  String get body;
  PrayerGrounding get grounding;
  PrayerPurpose get purpose;
  int get helpfulCount;
  bool get viewerMarkedHelpful;
  String? get action;
}

class PrayerDisplayValue implements PrayerDisplay {
  const PrayerDisplayValue({
    required this.reference,
    required this.title,
    required this.body,
    required this.grounding,
    required this.purpose,
    this.helpfulCount = 0,
    this.viewerMarkedHelpful = false,
    this.action,
  });

  @override
  final PrayerReference reference;
  @override
  String get id => reference.id;
  @override
  final String title;
  @override
  final String body;
  @override
  final PrayerGrounding grounding;
  @override
  final PrayerPurpose purpose;
  @override
  final int helpfulCount;
  @override
  final bool viewerMarkedHelpful;
  @override
  final String? action;
}

class LibraryPrayer implements PrayerDisplay {
  const LibraryPrayer({
    required this.id,
    required this.title,
    required this.body,
    required this.grounding,
    required this.purpose,
    required this.helpfulCount,
    required this.viewerMarkedHelpful,
    this.languageStyle = PrayerLanguageStyle.christian,
    this.action,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String body;
  @override
  final PrayerGrounding grounding;
  @override
  final PrayerPurpose purpose;
  @override
  final int helpfulCount;
  @override
  final bool viewerMarkedHelpful;
  final PrayerLanguageStyle languageStyle;
  @override
  final String? action;

  @override
  PrayerReference get reference => PrayerReference.library(id);
}
