import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/guide/data/guide_repository.dart';
import 'package:soulbuddy/features/guide/domain/guide_profile.dart';

void main() {
  test('name is saved trimmed and restored on a new repository', () async {
    final values = <String, String>{};
    GuideRepository create() => GuideRepository(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );
    expect(await create().load(), isNull);
    await create().save('  Arel  ');
    expect(await create().load(), 'Arel');
  });
  test('rejects empty and overlong names', () {
    expect(GuideProfile.validName('   '), isFalse);
    expect(GuideProfile.validName('a' * 41), isFalse);
    expect(GuideProfile.validName('Arel'), isTrue);
  });
  test('storage failure is propagated', () async {
    final repo = GuideRepository(
      read: (_) async => null,
      write: (_, _) async => throw StateError('failed'),
    );
    await expectLater(repo.save('Arel'), throwsStateError);
  });
}
