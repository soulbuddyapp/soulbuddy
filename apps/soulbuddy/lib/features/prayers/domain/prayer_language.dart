enum PrayerLanguageStyle {
  christian('christian'),
  catholic('catholic'),
  jesus('jesus');

  const PrayerLanguageStyle(this.wireValue);

  final String wireValue;

  static PrayerLanguageStyle fromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return PrayerLanguageStyle.christian;
  }
}

enum PrayerLanguagePreference {
  christian('christian', 'Christian'),
  catholic('catholic', 'Catholic'),
  jesus('jesus', 'Jesus'),
  all('all', 'All of the above');

  const PrayerLanguagePreference(this.wireValue, this.label);

  final String wireValue;
  final String label;

  List<PrayerLanguageStyle> get rankOrder => switch (this) {
    PrayerLanguagePreference.christian => const [
      PrayerLanguageStyle.christian,
      PrayerLanguageStyle.jesus,
      PrayerLanguageStyle.catholic,
    ],
    PrayerLanguagePreference.catholic => const [
      PrayerLanguageStyle.catholic,
      PrayerLanguageStyle.christian,
      PrayerLanguageStyle.jesus,
    ],
    PrayerLanguagePreference.jesus => const [
      PrayerLanguageStyle.jesus,
      PrayerLanguageStyle.christian,
      PrayerLanguageStyle.catholic,
    ],
    PrayerLanguagePreference.all => const [
      PrayerLanguageStyle.christian,
      PrayerLanguageStyle.catholic,
      PrayerLanguageStyle.jesus,
    ],
  };

  int rankOf(PrayerLanguageStyle style) {
    if (this == PrayerLanguagePreference.all) return 0;
    if (this == PrayerLanguagePreference.catholic &&
        style != PrayerLanguageStyle.catholic) {
      return 1;
    }
    return rankOrder.indexOf(style);
  }

  static PrayerLanguagePreference? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}
