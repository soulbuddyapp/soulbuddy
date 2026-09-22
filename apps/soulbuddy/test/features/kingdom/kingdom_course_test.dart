import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/kingdom/providers/kingdom_course_providers.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Kingdom course has seventeen playable and readable Nuggets', () async {
    final catalog = await loadKingdomCatalog();
    expect(catalog, hasLength(17));
    expect(catalog.first.title, 'Lay Down the Old Life');
    expect(catalog.last.title, 'Live Intentionally');
    for (final nugget in catalog) {
      expect(nugget.id, matches(RegExp(r'^\d{2}-')));
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

  test(
    'later Nuggets teach forgiveness, bodily dignity, and repentance',
    () async {
      final catalog = await loadKingdomCatalog();
      final texts = await Future.wait(
        catalog
            .skip(8)
            .take(3)
            .map((nugget) => rootBundle.loadString(nugget.transcriptAsset)),
      );
      expect(texts[0].toLowerCase(), contains('forgive'));
      expect(texts[0].toLowerCase(), contains('boundaries'));
      expect(texts[1].toLowerCase(), contains('body'));
      expect(texts[1].toLowerCase(), contains('worth'));
      expect(texts[1].toLowerCase(), contains('sin against god'));
      expect(texts[1].toLowerCase(), contains('drunkenness'));
      expect(texts[1].toLowerCase(), contains('chronic laziness'));
      expect(texts[2].toLowerCase(), contains('repent'));
      expect(texts[2].toLowerCase(), contains('door'));
    },
  );

  test('renewal Nuggets distinguish Scripture from mental shortcuts', () async {
    final catalog = await loadKingdomCatalog();
    final texts = await Future.wait(
      catalog
          .skip(11)
          .take(3)
          .map((nugget) => rootBundle.loadString(nugget.transcriptAsset)),
    );
    expect(texts[0].toLowerCase(), contains('subconscious'));
    expect(texts[0].toLowerCase(), contains('not a translation'));
    expect(texts[1].toLowerCase(), contains('morning, midday, and evening'));
    expect(texts[1].toLowerCase(), contains('not a spell'));
    expect(texts[2].toLowerCase(), contains('peter'));
    expect(texts[2].toLowerCase(), contains('doubt is not automatically'));
  });

  test(
    'later Nuggets pair dignity and connection with mercy and hope',
    () async {
      final catalog = await loadKingdomCatalog();
      final connection = await rootBundle.loadString(
        catalog[14].transcriptAsset,
      );
      final restoration = await rootBundle.loadString(
        catalog[15].transcriptAsset,
      );
      expect(connection.toLowerCase(), contains('loneliness'));
      expect(connection.toLowerCase(), contains('dignity'));
      expect(connection.toLowerCase(), contains('trusted person'));
      expect(restoration.toLowerCase(), contains('confess'));
      expect(restoration.toLowerCase(), contains('new adam'));
      expect(restoration.toLowerCase(), contains('healing'));
      expect(restoration.toLowerCase(), contains('not a guarantee'));
    },
  );

  test(
    'the new life Nugget joins awareness, repentance, and service',
    () async {
      final catalog = await loadKingdomCatalog();
      final text = (await rootBundle.loadString(
        catalog.last.transcriptAsset,
      )).toLowerCase();
      expect(text, contains('notice the lure'));
      expect(text, contains('apologize'));
      expect(text, contains('holy spirit'));
      expect(text, contains('bless'));
      expect(text, contains('rest'));
    },
  );

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
