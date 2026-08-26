import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_choices.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';

void main() {
  test('Jesus ranks direct Gospel content before Christian and Catholic', () {
    expect(PrayerLanguagePreference.jesus.rankOrder, const [
      PrayerLanguageStyle.jesus,
      PrayerLanguageStyle.christian,
      PrayerLanguageStyle.catholic,
    ]);
  });

  test('Christian and Catholic preserve the approved ordering', () {
    expect(PrayerLanguagePreference.christian.rankOrder, const [
      PrayerLanguageStyle.christian,
      PrayerLanguageStyle.jesus,
      PrayerLanguageStyle.catholic,
    ]);
    expect(
      PrayerLanguagePreference.catholic.rankOf(PrayerLanguageStyle.catholic),
      0,
    );
    expect(
      PrayerLanguagePreference.catholic.rankOf(PrayerLanguageStyle.christian),
      1,
    );
    expect(
      PrayerLanguagePreference.catholic.rankOf(PrayerLanguageStyle.jesus),
      1,
    );
  });

  test('All of the above gives every language style equal rank', () {
    for (final style in PrayerLanguageStyle.values) {
      expect(PrayerLanguagePreference.all.rankOf(style), 0);
    }
  });

  test('guided choices map to the existing generation contract', () {
    const answers = FirstPrayerAnswers(
      purpose: FirstPrayerPurpose.guidance,
      frequency: FirstPrayerFrequency.once,
      audience: FirstPrayerAudience.family,
      language: PrayerLanguagePreference.catholic,
    );

    expect(answers.style, PrayerStyle.situational);
    expect(answers.reach, PrayerReach.encompassing);
    expect(answers.grounding, PrayerGrounding.catholic);
    expect(answers.prayerPurpose, PrayerPurpose.guidance);
    expect(answers.beneficiaryChoice, 'family');
  });

  test('every displayed choice uses the approved short copy', () {
    expect(FirstPrayerPurpose.values.map((value) => value.label), [
      'Stay close',
      'Guidance',
      'Family',
      'Healing',
      'Forgiveness',
      'A difficult time',
    ]);
    expect(FirstPrayerFrequency.values.map((value) => value.label), [
      'Daily',
      'Once',
    ]);
    expect(FirstPrayerAudience.values.map((value) => value.label), [
      'Me',
      'Someone',
      'My family',
      'Others',
    ]);
    expect(PrayerLanguagePreference.values.map((value) => value.label), [
      'Christian',
      'Catholic',
      'Jesus',
      'All of the above',
    ]);
  });
}
