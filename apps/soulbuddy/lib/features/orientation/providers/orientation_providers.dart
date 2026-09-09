import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../application/orientation_player.dart';
import '../data/orientation_progress_repository.dart';
import '../domain/orientation_course.dart';

final orientationCatalogProvider = FutureProvider<List<OrientationCourse>>((
  ref,
) async {
  final data =
      jsonDecode(await rootBundle.loadString('assets/orientation/catalog.json'))
          as List;
  return data
      .map(
        (item) =>
            OrientationCourse.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
});
final orientationTranscriptProvider =
    FutureProvider.family<OrientationTranscript, String>((ref, path) async {
      return OrientationTranscript.fromJson(
        jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>,
      );
    });
final orientationProgressRepositoryProvider =
    Provider<OrientationProgressRepository>((ref) {
      final storage = ref.watch(secureStorageProvider);
      return OrientationProgressRepository(
        read: (key) => storage.read(key: key),
        write: (key, value) => storage.write(key: key, value: value),
      );
    });
final orientationPlayerFactoryProvider = Provider<OrientationPlayer Function()>(
  (ref) {
    return AudioplayersOrientationPlayer.new;
  },
);
final orientationSavedProgressProvider =
    FutureProvider.family<OrientationProgress, String>((ref, id) {
      return ref.watch(orientationProgressRepositoryProvider).load(id);
    });

class OrientationJourneyStatus {
  const OrientationJourneyStatus({
    required this.completedCount,
    required this.firstIncompleteId,
    required this.started,
    required this.complete,
  });

  final int completedCount;
  final String? firstIncompleteId;
  final bool started;
  final bool complete;
}

final orientationJourneyStatusProvider =
    FutureProvider<OrientationJourneyStatus>((ref) async {
      final catalog = await ref.watch(orientationCatalogProvider.future);
      final repository = ref.watch(orientationProgressRepositoryProvider);
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
    });
