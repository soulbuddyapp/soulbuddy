import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoulBuddy product architecture', () {
    test('keeps the approved five primary destinations in order', () {
      final router = File('lib/app/router.dart').readAsStringSync();
      final labels = RegExp(
        r"label:\s*'([^']+)'",
      ).allMatches(router).map((match) => match.group(1)).toList();

      expect(labels, ['Today', 'Goals', 'Record', 'Remember', 'Circles']);
      expect(router, contains("path: '/goals'"));
      expect(router, contains("path: '/prayers'"));
    });

    test('does not grow parallel-product primary destinations', () {
      final router = File('lib/app/router.dart').readAsStringSync();

      for (final label in const [
        'Recovery',
        'Freedom',
        'Purpose',
        'Coaching',
        'Addiction',
      ]) {
        expect(
          RegExp("label:\\s*'$label'").hasMatch(router),
          isFalse,
          reason: '$label must not become a primary SoulBuddy destination.',
        );
      }
    });

    test('SyntheticSpiritualContent legacy runtime boundary does not expand', () {
      const markers = [
        'PrayerDraftApi',
        'PrayerGenerationDispatcher',
        'prayerDraftProvider',
        'prayerGenerationWorkerProvider',
      ];
      const allowed = {
        'lib/core/config/app_config.dart',
        'lib/features/onboarding/providers/first_prayer_providers.dart',
        'lib/features/prayers/application/prayer_generation_dispatcher.dart',
        'lib/features/prayers/application/prayer_generation_worker.dart',
        'lib/features/prayers/data/laravel_prayer_draft_api.dart',
        'lib/features/prayers/data/prayer_draft_api.dart',
        'lib/features/prayers/presentation/prayer_draft_screen.dart',
        'lib/features/prayers/providers/personal_prayer_providers.dart',
      };

      final found = <String>{};
      for (final entity in Directory(
        'lib',
      ).listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (!markers.any(source.contains)) continue;
        found.add(_relativeLibPath(entity.path));
      }

      expect(
        found,
        equals(allowed),
        reason:
            'Runtime prayer generation is frozen legacy surface. New spiritual '
            'copy paths must use Scripture, reviewed content, or user words.',
      );
    });
  });
}

String _relativeLibPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.indexOf('lib/');
  return index < 0 ? normalized : normalized.substring(index);
}
