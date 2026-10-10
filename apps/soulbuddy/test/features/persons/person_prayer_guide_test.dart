import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/application/person_prayer_guide.dart';

void main() {
  test('places the person in the intercessory prayer', () {
    expect(personPrayerGuide('Mum'), contains('I present Mum to You today.'));
    expect(personPrayerGuide('Mum'), contains('mercy and forgiveness'));
  });
}
