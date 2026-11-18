import '../domain/formation_catalog.dart';

(String, String) teachingPrompts(FormationDay day) => switch (day.day) {
  1 => (
    'When did you last feel truly seen?',
    'Who could you help feel seen today?',
  ),
  2 => (
    'What do you reach for when life feels heavy?',
    'What could give you a moment of life today?',
  ),
  3 => (
    'What small choice has been troubling your conscience?',
    'What is one safer choice you can make next time?',
  ),
  _ => (day.reflection, day.action),
};
