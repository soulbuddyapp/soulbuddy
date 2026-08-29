import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';

void main() {
  test(
    'new generated prayer request is blocked before repository creation',
    () async {
      final repository = _GenerationRepository();
      final container = ProviderContainer(
        overrides: [
          prayerGenerationRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          prayerRequestCreationEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final provider = personalizedPrayerControllerProvider(null);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);

      controller.chooseStyle(PrayerStyle.daily);
      controller.chooseReach(PrayerReach.personal);
      controller.chooseGrounding(PrayerGrounding.generalChristian);
      controller.choosePurpose(PrayerPurpose.guidance);
      controller.setRequestText('Help me receive and use wisdom today.');
      await controller.continueFromRequest();

      expect(repository.createCalls, 0);
      expect(container.read(provider).hasError, isTrue);
    },
  );

  test(
    'existing local request still resumes while new creation is disabled',
    () async {
      final now = DateTime.utc(2026, 8, 29);
      final repository = _GenerationRepository(
        PrayerGenerationRequest(
          id: 'legacy-request',
          ownerId: 'owner-1',
          style: PrayerStyle.daily,
          reach: PrayerReach.personal,
          grounding: PrayerGrounding.generalChristian,
          purpose: PrayerPurpose.guidance,
          requestText: 'Help me receive and use wisdom today.',
          status: PrayerGenerationStatus.editing,
          attemptCount: 0,
          contexts: const [],
          createdAt: now,
          updatedAt: now,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          prayerGenerationRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          prayerRequestCreationEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        personalizedPrayerControllerProvider('legacy-request').future,
      );

      expect(state.request?.id, 'legacy-request');
      expect(state.step, PersonalizedPrayerStep.context);
      expect(repository.createCalls, 0);
    },
  );
}

class _GenerationRepository implements PrayerGenerationRepository {
  _GenerationRepository([this.current]);

  PrayerGenerationRequest? current;
  int createCalls = 0;

  @override
  Stream<PrayerGenerationRequest?> watch(String id) =>
      Stream.value(current?.id == id ? current : null);

  @override
  Stream<List<PrayerGenerationRequest>> watchPending() => const Stream.empty();

  @override
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    PrayerLanguagePreference? languagePreference,
    required String requestText,
  }) async {
    createCalls++;
    throw StateError('create should not be reached');
  }

  @override
  Future<void> update(PrayerGenerationRequest request) async {
    current = request;
  }

  @override
  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  ) async {}

  @override
  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  }) async {}

  @override
  Future<bool> claim(String requestId, String attemptId, DateTime now) async =>
      false;

  @override
  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  ) async {}

  @override
  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  }) async {}

  @override
  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  ) async {}
}
