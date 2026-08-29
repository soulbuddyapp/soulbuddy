import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/guards/data/bundled_guard_catalogue.dart';
import 'package:soulbuddy/features/guards/domain/guard_definition.dart';

void main() {
  test('bundled guard definitions are versioned, unique, and reviewed', () {
    final definitions = BundledGuardCatalogue.definitions;

    expect(definitions, isNotEmpty);
    expect(
      definitions.map((definition) => definition.id).toSet(),
      hasLength(definitions.length),
    );
    for (final definition in definitions) {
      expect(definition.id, matches(RegExp(r'^[a-z0-9][a-z0-9-]*$')));
      expect(definition.contentVersion, greaterThan(0));
      expect(definition.title.trim(), isNotEmpty);
      expect(definition.description.trim(), isNotEmpty);
      expect(definition.steps, isNotEmpty);
      expect(definition.reviewedAt.isUtc, isTrue);
    }
  });

  test('DNS guards carry provenance without making one provider mandatory', () {
    final filters = BundledGuardCatalogue.definitions
        .where((definition) => definition.kind == GuardKind.contentFilter)
        .toList();

    expect(filters.map((definition) => definition.id).toSet(), {
      'dns-adguard-family',
      'dns-cleanbrowsing-family',
      'dns-nextdns-configured',
    });
    expect(filters.every((definition) => definition.sourceUri != null), isTrue);
  });
}
