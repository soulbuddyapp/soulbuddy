import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoulBuddy product architecture', () {
    test('keeps the approved five primary destinations in order', () {
      final router = File('lib/app/router.dart').readAsStringSync();
      final labels = RegExp(
        r"label:\s*'([^']+)'",
      ).allMatches(router).map((match) => match.group(1)).toList();

      expect(labels, ['Today', 'Goals', 'Persons', 'Remember', 'Circles']);
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

    test('retired generated-prayer request routes stay unreachable', () {
      final router = File('lib/app/router.dart').readAsStringSync();

      expect(router, isNot(contains("path: 'requests/:requestId'")));
      expect(router, isNot(contains('PersonalizedPrayerScreen')));
      expect(router, isNot(contains('PrayerDraftScreen')));
      expect(router, contains("path: 'create'"));
      expect(router, contains("path: 'saved/:prayerId'"));
    });

    test('client config exposes no prayer-generation capability', () {
      final config = File('lib/core/config/app_config.dart').readAsStringSync();

      for (final marker in const [
        'prayerGenerationEnabled',
        'prayerRequestCreationEnabled',
        'prayerDraftProvider',
        'prayerDraftDisclosureVersion',
        'SOULBUDDY_PRAYER_GENERATION_ENABLED',
        'SOULBUDDY_PRAYER_REQUEST_CREATION_ENABLED',
        'SOULBUDDY_PRAYER_DRAFT_PROVIDER',
        'SOULBUDDY_PRAYER_DRAFT_DISCLOSURE_VERSION',
        'deepseek',
      ]) {
        expect(config, isNot(contains(marker)));
      }
    });

    test('historical generation storage is read-only in production', () {
      final contract = File(
        'lib/features/prayers/data/prayer_generation_repository.dart',
      ).readAsStringSync();
      final archive = File(
        'lib/features/prayers/data/powersync_prayer_generation_repository.dart',
      ).readAsStringSync();
      final personal = File(
        'lib/features/prayers/data/powersync_personal_prayer_repository.dart',
      ).readAsStringSync();

      expect(contract, contains('watch(String id)'));
      for (final marker in const [
        'create(',
        'update(',
        'replaceContexts(',
        'queue(',
        'claim(',
        'storeDraft(',
        'defer(',
        'requireAttention(',
        'watchPending(',
      ]) {
        expect(contract, isNot(contains(marker)));
      }
      expect(archive, contains('watch(String id)'));
      expect(
        archive,
        isNot(contains('INSERT INTO prayer_generation_requests')),
      );
      expect(archive, isNot(contains('UPDATE prayer_generation_requests')));
      expect(
        archive,
        isNot(contains('DELETE FROM prayer_generation_contexts')),
      );
      expect(
        personal,
        isNot(contains('UPDATE prayer_generation_requests')),
        reason:
            'Accepting a historical draft must not mutate the retired archive.',
      );
    });

    test('client synthetic spiritual generation runtime is absent', () {
      const markers = [
        'PrayerDraftApi',
        'LaravelPrayerDraftApi',
        'PrayerGenerationDispatcher',
        'PrayerGenerationWorker',
        'prayerDraftProvider',
        'prayerGenerationWorkerProvider',
        'prayerGenerationEnabled',
        'prayerRequestCreationEnabled',
        'SOULBUDDY_PRAYER_DRAFT_',
        'deepseek',
      ];

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
        isEmpty,
        reason:
            'Spiritual copy paths must use Scripture, reviewed content, or '
            'the user\'s own words; client generation runtime is retired.',
      );
    });

    test(
      'private spiritual content boundaries contain no logging or analytics',
      () {
        final targets = <File>[];
        for (final root in const ['lib/features/editorial']) {
          final directory = Directory(root);
          if (!directory.existsSync()) continue;
          targets.addAll(
            directory
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()
                .where((file) => file.path.endsWith('.dart')),
          );
        }
        for (final path in const [
          'lib/features/onboarding/providers/first_prayer_providers.dart',
          'lib/features/prayers/data/powersync_personal_prayer_repository.dart',
          'lib/features/prayers/data/powersync_prayer_generation_repository.dart',
          'lib/features/prayers/presentation/prayer_create_screen.dart',
          'lib/features/prayers/providers/personal_prayer_providers.dart',
        ]) {
          targets.add(File(path));
        }

        for (final file in targets) {
          final source = file.readAsStringSync();
          for (final marker in const [
            'print(',
            'debugPrint(',
            'developer.log(',
            'FirebaseAnalytics',
            'analytics.log',
            'telemetry',
          ]) {
            expect(
              source,
              isNot(contains(marker)),
              reason:
                  '${_relativeLibPath(file.path)} must not send or log private '
                  'prayer, request, context, or editorial-selection content.',
            );
          }
        }
      },
    );
  });
}

String _relativeLibPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.indexOf('lib/');
  return index < 0 ? normalized : normalized.substring(index);
}
