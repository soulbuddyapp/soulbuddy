import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/formation/data/formation_progress_repository.dart';
import 'package:soulbuddy/features/formation/domain/formation_reading.dart';

void main() {
  test('curriculum follows the reviewed thirteen-stage order', () {
    expect(formationReadings, hasLength(13));
    expect(formationReadings.first.reference, 'Romans 6:12–14');
    expect(formationReadings[11].practice, contains('Plant something good'));
    expect(formationReadings.last.reference, '2 Timothy 2:1–7');
  });

  test(
    'formation progress resumes at the first unfinished meditation',
    () async {
      String? stored;
      final repository = FormationProgressRepository(
        read: (_) async => stored,
        write: (_, value) async => stored = value,
      );

      await repository.complete('effects-of-sin');
      final progress = await repository.load();

      expect(progress.completedIds, {'effects-of-sin'});
      expect(progress.next(formationReadings).id, 'overcoming-sin');
    },
  );
}
