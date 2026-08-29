import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/guards/application/guard_recommendations.dart';
import 'package:soulbuddy/features/guards/data/bundled_guard_catalogue.dart';

void main() {
  test('gambling recommendations start with binding structural controls', () {
    final recommendations = recommendedGuardDefinitions(
      definitions: BundledGuardCatalogue.definitions,
      contextTag: 'gambling',
    );

    expect(
      recommendations.map((definition) => definition.id).take(2).toList(),
      ['gambling-self-exclusion', 'gambling-binding-limits'],
    );
    expect(
      recommendations.any(
        (definition) => definition.id == 'dns-adguard-family',
      ),
      isFalse,
    );
  });

  test('nicotine recommendations never invent content filtering', () {
    final recommendations = recommendedGuardDefinitions(
      definitions: BundledGuardCatalogue.definitions,
      contextTag: 'nicotine',
    );

    expect(recommendations, isNotEmpty);
    expect(
      recommendations.every(
        (definition) => definition.goalContextTags.contains('nicotine'),
      ),
      isTrue,
    );
    expect(
      recommendations.any((definition) => definition.id.startsWith('dns-')),
      isFalse,
    );
  });

  test('unknown or omitted context returns no presumed walls', () {
    expect(
      recommendedGuardDefinitions(
        definitions: BundledGuardCatalogue.definitions,
        contextTag: null,
      ),
      isEmpty,
    );
    expect(
      recommendedGuardDefinitions(
        definitions: BundledGuardCatalogue.definitions,
        contextTag: 'unknown',
      ),
      isEmpty,
    );
  });
}
