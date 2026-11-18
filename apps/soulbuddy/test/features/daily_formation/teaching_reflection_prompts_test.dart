import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_catalog.dart';
import 'package:soulbuddy/features/daily_formation/domain/teaching_reflection_prompts.dart';

FormationDay day(int number) => FormationDay(
  id: 'D',
  day: number,
  packId: 'P',
  focus: '',
  objective: '',
  scripture: '',
  reflection: 'Existing question',
  action: 'Existing action',
  videoIds: const [],
);
void main() {
  test('first teaching has specific personal questions', () {
    expect(teachingPrompts(day(1)), (
      'When did you last feel truly seen?',
      'Who could you help feel seen today?',
    ));
  });
  test('other teachings retain their existing questions', () {
    expect(teachingPrompts(day(40)), ('Existing question', 'Existing action'));
  });
}
