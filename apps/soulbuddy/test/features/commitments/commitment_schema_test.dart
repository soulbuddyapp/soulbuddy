import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/data/commitment_schema.dart';

void main() {
  test('only durable formation records are synced', () {
    final synced = commitmentTables
        .where((t) => !t.localOnly)
        .map((t) => t.name)
        .toSet();
    expect(synced, {
      'commitments',
      'commitment_practices',
      'commitment_declarations',
      'commitment_meditation_plans',
      'commitment_preparation_cycles',
      'commitment_meditation_sessions',
    });
    final local = commitmentTables
        .where((t) => t.localOnly)
        .map((t) => t.name)
        .toSet();
    expect(local, {
      'commitment_journey_progress',
      'commitment_journey_practice_drafts',
      'commitment_reminder_devices',
      'commitment_finalization_recovery',
      'commitment_personal_prayer_narration_cache',
    });
    for (final table in commitmentTables) {
      expect(
        table.columns.any((c) => c.name == 'owner_id'),
        isTrue,
        reason: table.name,
      );
    }
  });
}
