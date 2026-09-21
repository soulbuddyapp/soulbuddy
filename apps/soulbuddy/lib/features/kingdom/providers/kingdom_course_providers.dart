import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orientation/data/orientation_progress_repository.dart';
import '../../orientation/domain/orientation_course.dart';
import '../../orientation/providers/orientation_providers.dart';

Future<List<OrientationCourse>> loadKingdomCatalog() async {
  final raw =
      jsonDecode(await rootBundle.loadString('assets/kingdom/catalog.json'))
          as List;
  return List.unmodifiable(
    raw.map(
      (item) =>
          OrientationCourse.fromJson(Map<String, dynamic>.from(item as Map)),
    ),
  );
}

Future<OrientationJourneyStatus> loadKingdomJourney(
  List<OrientationCourse> catalog,
  OrientationProgressRepository repository,
) async {
  var completed = 0;
  var started = false;
  String? firstIncomplete;
  for (final nugget in catalog) {
    final progress = await repository.load(nugget.id);
    if (progress.completed) {
      completed++;
    } else {
      firstIncomplete ??= nugget.id;
    }
    started =
        started || progress.completed || progress.position > Duration.zero;
  }
  return OrientationJourneyStatus(
    completedCount: completed,
    firstIncompleteId: firstIncomplete,
    started: started,
    complete: catalog.isNotEmpty && completed == catalog.length,
  );
}

final kingdomCatalogProvider = FutureProvider<List<OrientationCourse>>(
  (ref) => loadKingdomCatalog(),
);

final kingdomJourneyStatusProvider = FutureProvider<OrientationJourneyStatus>((
  ref,
) async {
  final catalog = await ref.watch(kingdomCatalogProvider.future);
  final repository = ref.watch(orientationProgressRepositoryProvider);
  return loadKingdomJourney(catalog, repository);
});
