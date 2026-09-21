import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/kingdom/providers/kingdom_course_providers.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Kingdom course has eight playable and readable Nuggets', () async {
    final catalog = await loadKingdomCatalog();
    expect(catalog, hasLength(8));
    expect(catalog.first.title, 'Lay Down the Old Life');
    expect(catalog.last.title, 'Discern and Carry');
    for (final nugget in catalog) {
      expect(nugget.id, startsWith('0'));
      expect(nugget.audioAsset, startsWith('kingdom/'));
      expect(nugget.transcriptAsset, startsWith('assets/kingdom/'));
      final transcript = OrientationTranscript.fromJson(
        jsonDecode(await rootBundle.loadString(nugget.transcriptAsset))
            as Map<String, dynamic>,
      );
      expect(transcript.text, isNotEmpty);
      expect(transcript.words, isNotEmpty);
      expect(transcript.sentences, isNotEmpty);
      expect(
        transcript.words.last.endMs,
        lessThanOrEqualTo(nugget.duration.inMilliseconds),
      );
      final audio = await rootBundle.load('assets/${nugget.audioAsset}');
      expect(audio.lengthInBytes, greaterThan(20000));
    }
  });

  test('advanced Nuggets teach detachment and careful discernment', () async {
    final catalog = await loadKingdomCatalog();
    final detachment = await rootBundle.loadString(catalog[6].transcriptAsset);
    final discernment = await rootBundle.loadString(catalog[7].transcriptAsset);
    expect(detachment.toLowerCase(), contains('detachment'));
    expect(detachment.toLowerCase(), contains('entrust'));
    expect(discernment.toLowerCase(), contains('first thought'));
    expect(discernment.toLowerCase(), contains('bias'));
    expect(discernment.toLowerCase(), contains('prayer'));
  });

  test(
    'each Nugget opens a reflective question and gives the story room',
    () async {
      for (final nugget in await loadKingdomCatalog()) {
        final transcript = OrientationTranscript.fromJson(
          jsonDecode(await rootBundle.loadString(nugget.transcriptAsset))
              as Map<String, dynamic>,
        );
        final text = transcript.text.trim();
        expect(text, matches(RegExp(r'^[^.!?]{12,}\?')), reason: nugget.id);
        expect(
          text.split(RegExp(r'\s+')).length,
          greaterThanOrEqualTo(175),
          reason: nugget.id,
        );
        expect(
          text.split('\n\n').length,
          greaterThanOrEqualTo(3),
          reason: nugget.id,
        );
      }
    },
  );

  test('next Kingdom Nugget follows saved completion', () async {
    final catalog = await loadKingdomCatalog();
    final records = <String, String>{};
    final repository = OrientationProgressRepository(
      read: (key) async => records[key],
      write: (key, value) async => records[key] = value,
    );
    var journey = await loadKingdomJourney(catalog, repository);
    expect(journey.firstIncompleteId, catalog.first.id);
    expect(journey.complete, isFalse);

    await repository.save(
      catalog.first.id,
      const OrientationProgress(completed: true),
    );
    journey = await loadKingdomJourney(catalog, repository);
    expect(journey.completedCount, 1);
    expect(journey.firstIncompleteId, catalog[1].id);
  });

  test(
    'existing goal meditation stays available while advanced Nuggets remain',
    () async {
      final catalog = await loadKingdomCatalog();
      final records = <String, String>{};
      final repository = OrientationProgressRepository(
        read: (key) async => records[key],
        write: (key, value) async => records[key] = value,
      );
      for (final nugget in catalog.take(6)) {
        await repository.save(
          nugget.id,
          const OrientationProgress(completed: true),
        );
      }
      expect((await loadKingdomJourney(catalog, repository)).complete, isFalse);
      expect(await loadKingdomMeditationReadiness(catalog, repository), isTrue);
    },
  );
}
