import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../record/domain/encounter.dart';
import '../../scripture/data/bundled_scripture_source.dart';
import '../../scripture/data/scripture_repository.dart';
import '../../scripture/domain/scripture_passage.dart';
import '../application/prayer_generation_dispatcher.dart';
import '../application/prayer_generation_worker.dart';
import '../data/laravel_prayer_draft_api.dart';
import '../data/personal_prayer_repository.dart';
import '../data/powersync_personal_prayer_repository.dart';
import '../data/powersync_prayer_generation_repository.dart';
import '../data/prayer_draft_api.dart';
import '../data/prayer_generation_repository.dart';
import '../domain/library_prayer.dart';
import '../domain/prayer_generation_request.dart';
import '../domain/prayer_language.dart';
import '../domain/personal_prayer.dart';

final prayerGenerationRepositoryProvider =
    FutureProvider<PrayerGenerationRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncPrayerGenerationRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
      );
    });

final personalPrayerRepositoryProvider =
    FutureProvider<PersonalPrayerRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncPersonalPrayerRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
        deviceId: identity.deviceId,
      );
    });

final prayerDraftApiProvider = Provider<PrayerDraftApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  final configured = Uri.tryParse(AppConfig.apiBaseUrl);
  final apiBaseUri = configured != null && configured.hasScheme
      ? configured
      : Uri.parse('http://127.0.0.1');
  return LaravelPrayerDraftApi(
    apiBaseUri: apiBaseUri,
    accessToken: ref.watch(appSessionTokenReaderProvider),
    client: client,
  );
});

final prayerGenerationDispatcherProvider =
    FutureProvider<PrayerGenerationDispatcher>((ref) async {
      return PrayerGenerationDispatcher(
        repository: await ref.watch(prayerGenerationRepositoryProvider.future),
        api: ref.watch(prayerDraftApiProvider),
      );
    });

final prayerGenerationRequestProvider = StreamProvider.autoDispose
    .family<PrayerGenerationRequest?, String>((ref, requestId) async* {
      final repository = await ref.watch(
        prayerGenerationRepositoryProvider.future,
      );
      yield* repository.watch(requestId);
    });

final personalPrayerProvider = StreamProvider.autoDispose
    .family<PersonalPrayer?, String>((ref, prayerId) async* {
      final repository = await ref.watch(
        personalPrayerRepositoryProvider.future,
      );
      yield* repository.watch(prayerId);
    });

final prayerGenerationWorkerProvider = FutureProvider<PrayerGenerationWorker>((
  ref,
) async {
  await ref.watch(installationSessionBootstrapProvider.future);
  final worker = PrayerGenerationWorker(
    repository: await ref.watch(prayerGenerationRepositoryProvider.future),
    dispatcher: await ref.watch(prayerGenerationDispatcherProvider.future),
  );
  worker.start();
  ref.onDispose(() => unawaited(worker.dispose()));
  return worker;
});

final scriptureRepositoryProvider = Provider<ScriptureRepository>(
  (ref) => const BundledScriptureRepository(),
);

final personalizedPrayerControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PersonalizedPrayerController, PersonalizedPrayerFlowState, String?>(
      (requestId) => PersonalizedPrayerController(requestId),
    );

enum PersonalizedPrayerStep {
  style,
  reach,
  grounding,
  purpose,
  request,
  beneficiary,
  surrender,
  responsibility,
  alignment,
  context,
}

class PersonalizedPrayerFlowState {
  const PersonalizedPrayerFlowState({
    required this.step,
    this.request,
    this.style,
    this.reach,
    this.grounding,
    this.purpose,
    this.requestText = '',
  });

  final PersonalizedPrayerStep step;
  final PrayerGenerationRequest? request;
  final PrayerStyle? style;
  final PrayerReach? reach;
  final PrayerGrounding? grounding;
  final PrayerPurpose? purpose;
  final String requestText;

  PersonalizedPrayerFlowState copyWith({
    PersonalizedPrayerStep? step,
    PrayerGenerationRequest? request,
    PrayerStyle? style,
    PrayerReach? reach,
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    String? requestText,
  }) {
    return PersonalizedPrayerFlowState(
      step: step ?? this.step,
      request: request ?? this.request,
      style: style ?? this.style,
      reach: reach ?? this.reach,
      grounding: grounding ?? this.grounding,
      purpose: purpose ?? this.purpose,
      requestText: requestText ?? this.requestText,
    );
  }
}

class PersonalizedPrayerController
    extends AsyncNotifier<PersonalizedPrayerFlowState> {
  PersonalizedPrayerController(this.requestId);

  final String? requestId;

  @override
  Future<PersonalizedPrayerFlowState> build() async {
    if (requestId == null) {
      return const PersonalizedPrayerFlowState(
        step: PersonalizedPrayerStep.style,
      );
    }
    final repository = await ref.watch(
      prayerGenerationRepositoryProvider.future,
    );
    final request = await repository.watch(requestId!).first;
    if (request == null) {
      throw StateError('This prayer request is no longer available.');
    }
    return PersonalizedPrayerFlowState(
      step: _resumeStep(request),
      request: request,
      style: request.style,
      reach: request.reach,
      grounding: request.grounding,
      purpose: request.purpose,
      requestText: request.requestText,
    );
  }

  void chooseStyle(PrayerStyle value) =>
      _set(_value.copyWith(style: value, step: PersonalizedPrayerStep.reach));

  void chooseReach(PrayerReach value) => _set(
    _value.copyWith(reach: value, step: PersonalizedPrayerStep.grounding),
  );

  void chooseGrounding(PrayerGrounding value) => _set(
    _value.copyWith(grounding: value, step: PersonalizedPrayerStep.purpose),
  );

  void choosePurpose(PrayerPurpose value) => _set(
    _value.copyWith(purpose: value, step: PersonalizedPrayerStep.request),
  );

  void setRequestText(String value) =>
      _set(_value.copyWith(requestText: value));

  Future<void> continueFromRequest() async {
    final current = _value;
    final requestText = current.requestText.trim();
    if (requestText.isEmpty || requestText.length > 500) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = await ref.read(
        prayerGenerationRepositoryProvider.future,
      );
      final request = current.request == null
          ? await repository.create(
              style: current.style!,
              reach: current.reach!,
              grounding: current.grounding!,
              purpose: current.purpose!,
              languagePreference: current.grounding == PrayerGrounding.catholic
                  ? PrayerLanguagePreference.catholic
                  : PrayerLanguagePreference.christian,
              requestText: requestText,
            )
          : current.request!.copyWith(requestText: requestText);
      if (current.request != null) await repository.update(request);
      return current.copyWith(
        request: request,
        requestText: requestText,
        step: request.style == PrayerStyle.situational
            ? PersonalizedPrayerStep.beneficiary
            : PersonalizedPrayerStep.context,
      );
    });
  }

  Future<void> chooseBeneficiary(String value) => _updateRequest(
    (request) => request.copyWith(beneficiaryChoice: value),
    PersonalizedPrayerStep.surrender,
  );

  Future<void> chooseSurrender(String value) => _updateRequest(
    (request) => request.copyWith(surrenderChoice: value),
    PersonalizedPrayerStep.responsibility,
  );

  Future<void> chooseResponsibility(String value) => _updateRequest(
    (request) => request.copyWith(responsibilityChoice: value),
    PersonalizedPrayerStep.alignment,
  );

  Future<void> chooseAlignment(String value) => _updateRequest(
    (request) => request.copyWith(alignmentChoice: value),
    PersonalizedPrayerStep.context,
  );

  Future<void> addEncounter(Encounter encounter) async {
    final excerpt = encounter.body.trim();
    final snapshot = excerpt.length <= 2000
        ? excerpt
        : excerpt.substring(0, 2000);
    await _replaceContext(
      PrayerGenerationContext.encounter(
        sourceId: encounter.id,
        displayLabel: encounter.title,
        excerptSnapshot: snapshot,
      ),
    );
  }

  Future<void> addScripture({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
    required ScripturePassage passage,
  }) async {
    if (lastVerse < firstVerse || lastVerse - firstVerse + 1 > 20) {
      throw ArgumentError('Choose no more than 20 consecutive verses.');
    }
    await _replaceContext(
      PrayerGenerationContext.scripture(
        sourceId: '$book-$chapter-$firstVerse-$lastVerse',
        displayLabel: passage.reference,
        excerptSnapshot: passage.verses
            .map((verse) => '${verse.number} ${verse.text}')
            .join('\n'),
        translation: 'RSVCE',
        book: book,
        chapter: chapter,
        firstVerse: firstVerse,
        lastVerse: lastVerse,
      ),
    );
  }

  Future<String> prepareDraft() async {
    final request = _value.request!;
    final repository = await ref.read(
      prayerGenerationRepositoryProvider.future,
    );
    await repository.queue(
      request.id,
      provider: AppConfig.prayerDraftProvider,
      disclosureVersion: AppConfig.prayerDraftDisclosureVersion,
    );
    final dispatcher = await ref.read(
      prayerGenerationDispatcherProvider.future,
    );
    unawaited(dispatcher.dispatch(request.id));
    return request.id;
  }

  void goBack() {
    final current = _value;
    final previous = switch (current.step) {
      PersonalizedPrayerStep.style => PersonalizedPrayerStep.style,
      PersonalizedPrayerStep.reach => PersonalizedPrayerStep.style,
      PersonalizedPrayerStep.grounding => PersonalizedPrayerStep.reach,
      PersonalizedPrayerStep.purpose => PersonalizedPrayerStep.grounding,
      PersonalizedPrayerStep.request => PersonalizedPrayerStep.purpose,
      PersonalizedPrayerStep.beneficiary => PersonalizedPrayerStep.request,
      PersonalizedPrayerStep.surrender => PersonalizedPrayerStep.beneficiary,
      PersonalizedPrayerStep.responsibility => PersonalizedPrayerStep.surrender,
      PersonalizedPrayerStep.alignment => PersonalizedPrayerStep.responsibility,
      PersonalizedPrayerStep.context =>
        current.style == PrayerStyle.situational
            ? PersonalizedPrayerStep.alignment
            : PersonalizedPrayerStep.request,
    };
    _set(current.copyWith(step: previous));
  }

  PersonalizedPrayerFlowState get _value => state.requireValue;

  void _set(PersonalizedPrayerFlowState value) {
    state = AsyncData(value);
  }

  Future<void> _updateRequest(
    PrayerGenerationRequest Function(PrayerGenerationRequest) transform,
    PersonalizedPrayerStep next,
  ) async {
    final current = _value;
    final updated = transform(current.request!);
    _set(current.copyWith(request: updated, step: next));
    try {
      final repository = await ref.read(
        prayerGenerationRepositoryProvider.future,
      );
      await repository.update(updated);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _replaceContext(PrayerGenerationContext context) async {
    final current = _value;
    final request = current.request!;
    final contexts = [
      ...request.contexts.where((item) => item.type != context.type),
      context,
    ];
    final repository = await ref.read(
      prayerGenerationRepositoryProvider.future,
    );
    await repository.replaceContexts(request.id, contexts);
    _set(current.copyWith(request: request.copyWith(contexts: contexts)));
  }
}

PersonalizedPrayerStep _resumeStep(PrayerGenerationRequest request) {
  if (request.style == PrayerStyle.daily) {
    return PersonalizedPrayerStep.context;
  }
  if (request.beneficiaryChoice == null) {
    return PersonalizedPrayerStep.beneficiary;
  }
  if (request.surrenderChoice == null) {
    return PersonalizedPrayerStep.surrender;
  }
  if (request.responsibilityChoice == null) {
    return PersonalizedPrayerStep.responsibility;
  }
  if (request.alignmentChoice == null) {
    return PersonalizedPrayerStep.alignment;
  }
  return PersonalizedPrayerStep.context;
}
