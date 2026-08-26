import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/prayer_generation_request.dart';
import '../../prayers/domain/prayer_language.dart';

export '../../prayers/domain/prayer_language.dart';

enum FirstPrayerPurpose {
  stayClose('stay_close', 'Stay close'),
  guidance('guidance', 'Guidance'),
  family('family', 'Family'),
  healing('healing', 'Healing'),
  forgiveness('forgiveness', 'Forgiveness'),
  difficultTime('difficult_time', 'A difficult time');

  const FirstPrayerPurpose(this.wireValue, this.label);

  final String wireValue;
  final String label;

  PrayerPurpose get prayerPurpose => switch (this) {
    FirstPrayerPurpose.stayClose => PrayerPurpose.daily,
    FirstPrayerPurpose.guidance => PrayerPurpose.guidance,
    FirstPrayerPurpose.family => PrayerPurpose.family,
    FirstPrayerPurpose.healing => PrayerPurpose.healing,
    FirstPrayerPurpose.forgiveness => PrayerPurpose.forgiveness,
    FirstPrayerPurpose.difficultTime => PrayerPurpose.difficultTime,
  };

  static FirstPrayerPurpose? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum FirstPrayerFrequency {
  daily('daily', 'Daily'),
  once('once', 'Once');

  const FirstPrayerFrequency(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FirstPrayerFrequency? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum FirstPrayerAudience {
  me('me', 'Me'),
  someone('someone', 'Someone'),
  family('family', 'My family'),
  others('others', 'Others');

  const FirstPrayerAudience(this.wireValue, this.label);

  final String wireValue;
  final String label;

  PrayerReach get reach => this == FirstPrayerAudience.me
      ? PrayerReach.personal
      : PrayerReach.encompassing;

  static FirstPrayerAudience? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

class FirstPrayerAnswers {
  const FirstPrayerAnswers({
    this.purpose,
    this.frequency,
    this.audience,
    this.language,
    this.detail,
  });

  final FirstPrayerPurpose? purpose;
  final FirstPrayerFrequency? frequency;
  final FirstPrayerAudience? audience;
  final PrayerLanguagePreference? language;
  final String? detail;

  PrayerStyle get style => frequency == FirstPrayerFrequency.once
      ? PrayerStyle.situational
      : PrayerStyle.daily;
  PrayerReach get reach => audience?.reach ?? PrayerReach.personal;
  PrayerGrounding get grounding => language == PrayerLanguagePreference.catholic
      ? PrayerGrounding.catholic
      : PrayerGrounding.generalChristian;
  PrayerPurpose get prayerPurpose =>
      purpose?.prayerPurpose ?? PrayerPurpose.daily;
  String get beneficiaryChoice => switch (audience) {
    FirstPrayerAudience.me || null => 'me',
    FirstPrayerAudience.someone => 'another_person',
    FirstPrayerAudience.family => 'household_family',
    FirstPrayerAudience.others => 'people_affected',
  };

  String get requestText {
    final base = switch (purpose) {
      FirstPrayerPurpose.stayClose => 'Help me stay close to you.',
      FirstPrayerPurpose.guidance => 'Guide me in your way.',
      FirstPrayerPurpose.family => 'Hold my family close and guide us.',
      FirstPrayerPurpose.healing => 'Bring healing according to your will.',
      FirstPrayerPurpose.forgiveness => 'Lead me in forgiveness and mercy.',
      FirstPrayerPurpose.difficultTime =>
        'Keep me faithful through this difficult time.',
      null => 'Help me return to you in prayer.',
    };
    final personal = detail?.trim();
    return personal == null || personal.isEmpty ? base : '$base $personal';
  }

  FirstPrayerAnswers copyWith({
    FirstPrayerPurpose? purpose,
    FirstPrayerFrequency? frequency,
    FirstPrayerAudience? audience,
    PrayerLanguagePreference? language,
    String? detail,
    bool clearDetail = false,
  }) {
    return FirstPrayerAnswers(
      purpose: purpose ?? this.purpose,
      frequency: frequency ?? this.frequency,
      audience: audience ?? this.audience,
      language: language ?? this.language,
      detail: clearDetail ? null : detail ?? this.detail,
    );
  }
}
