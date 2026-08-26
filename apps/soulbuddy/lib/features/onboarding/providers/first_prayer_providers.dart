import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/prayer_generation_request.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/data/audio_asset_store.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/domain/encounter.dart';
import '../../record/domain/encounter_draft.dart';
import '../../record/providers/encounter_providers.dart';
import '../data/first_prayer_progress_repository.dart';
import '../data/powersync_first_prayer_progress_repository.dart';
import '../domain/first_prayer_choices.dart';
import '../domain/first_prayer_progress.dart';

final firstPrayerProgressRepositoryProvider =
    FutureProvider<FirstPrayerProgressRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      return PowerSyncFirstPrayerProgressRepository(
        database: database.powersync,
      );
    });

final firstPrayerSavedProgressProvider = FutureProvider<FirstPrayerProgress?>((
  ref,
) async {
  final repository = await ref.watch(
    firstPrayerProgressRepositoryProvider.future,
  );
  return repository.load();
});

final firstPrayerControllerProvider =
    AsyncNotifierProvider.autoDispose<FirstPrayerController, FirstPrayerState>(
      FirstPrayerController.new,
    );

class FirstPrayerResult {
  const FirstPrayerResult({
    required this.title,
    required this.body,
    required this.grounding,
    required this.purpose,
    required this.reference,
    this.action,
    this.requestId,
    this.revisionId,
  });

  final String title;
  final String body;
  final String? action;
  final PrayerGrounding grounding;
  final PrayerPurpose purpose;
  final PrayerReference reference;
  final String? requestId;
  final String? revisionId;

  bool get isGenerated => requestId != null;

  FirstPrayerResult copyWith({
    PrayerReference? reference,
    String? revisionId,
  }) => FirstPrayerResult(
    title: title,
    body: body,
    action: action,
    grounding: grounding,
    purpose: purpose,
    reference: reference ?? this.reference,
    requestId: requestId,
    revisionId: revisionId ?? this.revisionId,
  );
}

class FirstPrayerState {
  const FirstPrayerState({
    required this.progress,
    this.result,
    this.detailByVoice = false,
    this.remembranceType,
    this.remembranceByVoice = false,
    this.remembranceAudio,
  });

  final FirstPrayerProgress progress;
  final FirstPrayerResult? result;
  final bool detailByVoice;
  final MemoryType? remembranceType;
  final bool remembranceByVoice;
  final MemoryAudioDraft? remembranceAudio;

  FirstPrayerState copyWith({
    FirstPrayerProgress? progress,
    FirstPrayerResult? result,
    bool clearResult = false,
    bool? detailByVoice,
    MemoryType? remembranceType,
    bool? remembranceByVoice,
    MemoryAudioDraft? remembranceAudio,
  }) => FirstPrayerState(
    progress: progress ?? this.progress,
    result: clearResult ? null : result ?? this.result,
    detailByVoice: detailByVoice ?? this.detailByVoice,
    remembranceType: remembranceType ?? this.remembranceType,
    remembranceByVoice: remembranceByVoice ?? this.remembranceByVoice,
    remembranceAudio: remembranceAudio ?? this.remembranceAudio,
  );
}

class FirstPrayerController extends AsyncNotifier<FirstPrayerState> {
  var _preparationEpoch = 0;

  @override
  Future<FirstPrayerState> build() async {
    final progressRepository = await ref.watch(
      firstPrayerProgressRepositoryProvider.future,
    );
    var progress = await progressRepository.load();
    if (progress == null) {
      progress = const FirstPrayerProgress();
      await progressRepository.save(progress);
    }
    var result = await _restoreResult(progress);
    if (progress.stage == FirstPrayerStage.preparing) {
      progress = progress.copyWith(
        stage: result == null
            ? FirstPrayerStage.detailChoice
            : FirstPrayerStage.prayer,
      );
      await progressRepository.save(progress);
    } else if (progress.stage.index >= FirstPrayerStage.prayer.index &&
        result == null) {
      progress = progress.copyWith(stage: FirstPrayerStage.detailChoice);
      await progressRepository.save(progress);
    }
    MemoryType? remembranceType;
    try {
      final savedType = progress.remembranceType;
      if (savedType != null) {
        remembranceType = MemoryType.values.byName(savedType);
      }
    } on Object {
      remembranceType = null;
    }
    MemoryAudioDraft? remembranceAudio;
    try {
      final temporaryKey = progress.remembranceAudioTemporaryKey;
      final mimeType = progress.remembranceAudioMimeType;
      final durationMs = progress.remembranceAudioDurationMs;
      final waveform = progress.remembranceAudioWaveform;
      if (temporaryKey != null &&
          mimeType != null &&
          durationMs != null &&
          waveform != null) {
        remembranceAudio = MemoryAudioDraft(
          temporaryKey: temporaryKey,
          mimeType: mimeType,
          duration: Duration(milliseconds: durationMs),
          waveform: waveform,
        );
      }
    } on Object {
      remembranceAudio = null;
    }
    return FirstPrayerState(
      progress: progress,
      result: result,
      detailByVoice: progress.detailByVoice ?? false,
      remembranceType: remembranceType,
      remembranceByVoice: progress.remembranceByVoice ?? false,
      remembranceAudio: remembranceAudio,
    );
  }

  Future<void> choosePurpose(FirstPrayerPurpose purpose) => _advance(
    answers: _value.progress.answers.copyWith(purpose: purpose),
    stage: FirstPrayerStage.frequency,
  );

  Future<void> chooseFrequency(FirstPrayerFrequency frequency) => _advance(
    answers: _value.progress.answers.copyWith(frequency: frequency),
    stage: FirstPrayerStage.audience,
  );

  Future<void> chooseAudience(FirstPrayerAudience audience) => _advance(
    answers: _value.progress.answers.copyWith(audience: audience),
    stage: FirstPrayerStage.language,
  );

  Future<void> chooseLanguage(PrayerLanguagePreference language) => _advance(
    answers: _value.progress.answers.copyWith(language: language),
    stage: FirstPrayerStage.detailChoice,
  );

  Future<void> openDetail({required bool speak}) async {
    _emit(AppFeedbackIntent.selection);
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.detail,
      detailByVoice: speak,
    );
    state = AsyncData(
      _value.copyWith(progress: progress, detailByVoice: speak),
    );
    await _persist(progress);
  }

  Future<void> prepare({
    String? detail,
    required bool externalProcessingConsent,
  }) async {
    if (!externalProcessingConsent) {
      await usePreparedPrayer();
      return;
    }
    final preparationEpoch = ++_preparationEpoch;
    final answers = _value.progress.answers.copyWith(
      detail: detail,
      clearDetail: detail == null || detail.trim().isEmpty,
    );
    await _advance(answers: answers, stage: FirstPrayerStage.preparing);
    try {
      final generationRepository = await ref.read(
        prayerGenerationRepositoryProvider.future,
      );
      var request = await generationRepository.create(
        style: answers.style,
        reach: answers.reach,
        grounding: answers.grounding,
        purpose: answers.prayerPurpose,
        languagePreference: answers.language,
        requestText: answers.requestText,
      );
      if (answers.style == PrayerStyle.situational) {
        request = request.copyWith(
          beneficiaryChoice: answers.beneficiaryChoice,
          surrenderChoice: 'all',
          responsibilityChoice: 'act_faithfully',
          alignmentChoice: 'no_conflict_seen',
        );
        await generationRepository.update(request);
      }
      await generationRepository.queue(
        request.id,
        provider: AppConfig.prayerDraftProvider,
        disclosureVersion: AppConfig.prayerDraftDisclosureVersion,
      );
      await _saveProgress(_value.progress.copyWith(requestId: request.id));
      final dispatcher = await ref.read(
        prayerGenerationDispatcherProvider.future,
      );
      await dispatcher.dispatch(request.id);
      if (preparationEpoch != _preparationEpoch) return;
      final completed = await generationRepository.watch(request.id).first;
      if (preparationEpoch != _preparationEpoch) return;
      if (completed?.status == PrayerGenerationStatus.ready &&
          completed?.draftBody?.trim().isNotEmpty == true) {
        await _showGenerated(completed!);
        return;
      }
    } on Object {
      // A prepared prayer is always the quiet offline path.
    }
    if (preparationEpoch == _preparationEpoch) {
      await _usePreparedPrayer(cancelInFlight: false);
    }
  }

  Future<void> usePreparedPrayer() => _usePreparedPrayer(cancelInFlight: true);

  Future<void> _usePreparedPrayer({required bool cancelInFlight}) async {
    if (cancelInFlight) _preparationEpoch++;
    try {
      final answers = _value.progress.answers;
      final repository = await ref.read(prayerRepositoryProvider.future);
      var prayers = await repository
          .watchLibrary(
            purpose: answers.prayerPurpose,
            languagePreference: answers.language,
          )
          .first;
      if (prayers.isEmpty) {
        prayers = await repository
            .watchLibrary(languagePreference: answers.language)
            .first;
      }
      if (prayers.isNotEmpty) {
        await _showLibrary(prayers.first);
        return;
      }
    } on Object {
      // The bundled library is expected to be present; preserve an exit if it
      // is not rather than keeping someone on a loading screen.
      _retryPrayerRepository();
    }
    final fallback = _lastResortPrayer();
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.prayer,
      selectedPrayerType: 'prepared',
      selectedPrayerId: fallback.reference.id,
    );
    state = AsyncData(_value.copyWith(progress: progress, result: fallback));
    await _persist(progress);
  }

  Future<void> goBack() async {
    final current = _value.progress;
    final previous = switch (current.stage) {
      FirstPrayerStage.purpose => FirstPrayerStage.purpose,
      FirstPrayerStage.frequency => FirstPrayerStage.purpose,
      FirstPrayerStage.audience => FirstPrayerStage.frequency,
      FirstPrayerStage.language => FirstPrayerStage.audience,
      FirstPrayerStage.detailChoice => FirstPrayerStage.language,
      FirstPrayerStage.detail => FirstPrayerStage.detailChoice,
      FirstPrayerStage.preparing => FirstPrayerStage.detailChoice,
      _ => current.stage,
    };
    await _saveProgress(current.copyWith(stage: previous));
  }

  Future<bool> keepPrayer({required bool recordPractice}) async {
    var result = _value.result;
    if (result == null) return false;
    try {
      if (result.isGenerated && result.revisionId == null) {
        final repository = await ref.read(
          personalPrayerRepositoryProvider.future,
        );
        final prayer = await repository.accept(
          requestId: result.requestId!,
          title: result.title,
          body: result.body,
          action: result.action,
        );
        result = result.copyWith(
          reference: prayer.reference,
          revisionId: prayer.currentRevisionId,
        );
      }
      final todayRepository = await ref.read(prayerRepositoryProvider.future);
      await todayRepository.selectForToday(
        result.reference,
        includeAction: result.action?.trim().isNotEmpty == true,
      );
      ref.invalidate(todayPrayerProvider);
      if (recordPractice) {
        final practiceRepository = await ref.read(
          prayerPracticeRepositoryProvider.future,
        );
        final timezone = await ref.read(prayerDeviceTimezoneProvider)();
        await practiceRepository.recordSession(
          prayer: result.reference,
          revisionId: result.revisionId,
          timezone: timezone,
          idempotencyKey:
              'guided-first-prayer-${result.requestId ?? result.reference.id}',
        );
      }
    } on Object {
      state = AsyncData(_value.copyWith(result: result));
      _retryPrayerRepository();
      return false;
    }
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.practice,
      selectedPrayerType: result.reference.source == PrayerSource.personal
          ? 'personal'
          : null,
      selectedPrayerId: result.reference.id,
      selectedPrayerRevisionId: result.revisionId,
    );
    state = AsyncData(_value.copyWith(progress: progress, result: result));
    _emit(
      recordPractice
          ? AppFeedbackIntent.prayerCompleted
          : AppFeedbackIntent.saved,
    );
    await _persist(progress);
    return true;
  }

  Future<void> continueFromPractice() => _saveProgress(
    _value.progress.copyWith(stage: FirstPrayerStage.remembranceType),
  );

  Future<void> chooseRemembranceType(MemoryType type) async {
    _emit(AppFeedbackIntent.selection);
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.remembranceMode,
      remembranceType: type.name,
    );
    state = AsyncData(
      _value.copyWith(progress: progress, remembranceType: type),
    );
    await _persist(progress);
  }

  Future<void> chooseRemembranceMode({required bool speak}) async {
    _emit(AppFeedbackIntent.selection);
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.remembrance,
      remembranceByVoice: speak,
    );
    state = AsyncData(
      _value.copyWith(progress: progress, remembranceByVoice: speak),
    );
    await _persist(progress);
  }

  Future<bool> saveRemembrance({
    String body = '',
    MemoryAudioDraft? audio,
  }) async {
    final type = _value.remembranceType;
    if (type == null) return false;
    var durableAudio = audio;
    AudioAssetStore? stagedAssetStore;
    if (kIsWeb && audio != null) {
      try {
        final assetStore = await ref.read(audioAssetStoreProvider.future);
        if (assetStore is DurableTemporaryAudioStore) {
          final durableStore = assetStore as DurableTemporaryAudioStore;
          final staged = await durableStore.stageTemporary(
            TemporaryAudio(key: const Uuid().v7(), locator: audio.temporaryKey),
            mimeType: audio.mimeType,
          );
          durableAudio = MemoryAudioDraft(
            temporaryKey: staged.locator,
            mimeType: audio.mimeType,
            duration: audio.duration,
            waveform: audio.waveform,
          );
          stagedAssetStore = assetStore;
        }
      } on Object {
        return false;
      }
    }
    final retryProgress = _value.progress.copyWith(
      remembranceText: body.trim(),
      remembranceAudioTemporaryKey: durableAudio?.temporaryKey,
      remembranceAudioMimeType: durableAudio?.mimeType,
      remembranceAudioDurationMs: durableAudio?.duration.inMilliseconds,
      remembranceAudioWaveform: durableAudio?.waveform,
    );
    await _saveProgress(retryProgress);
    if (durableAudio != null) {
      state = AsyncData(_value.copyWith(remembranceAudio: durableAudio));
    }
    try {
      final now = DateTime.now();
      final repository = await ref.read(encounterRepositoryProvider.future);
      await repository.create(
        EncounterDraft(
          title: '${_memoryLabel(type)} · ${_memoryDate(now)}',
          body: body.trim(),
          occurredOn: _dateOnly(now),
          isAltar: false,
          memoryType: type,
          sensitive: false,
          recallEnabled: true,
          audio: durableAudio,
        ),
      );
      ref.invalidate(encountersProvider);
      _emit(AppFeedbackIntent.saved);
      if (stagedAssetStore != null &&
          durableAudio!.temporaryKey.startsWith('staged:')) {
        try {
          await stagedAssetStore.discardTemporary(durableAudio.temporaryKey);
        } on Object {
          // Old staged bytes are removed by private-audio cleanup if needed.
        }
      }
    } on Object {
      return false;
    }
    await complete();
    return true;
  }

  Future<void> complete() async {
    try {
      final repository = await ref.read(
        firstPrayerProgressRepositoryProvider.future,
      );
      await repository.clear();
      ref.invalidate(firstPrayerSavedProgressProvider);
    } on Object {
      // The welcome flag has already been completed by the gate.
    }
  }

  FirstPrayerState get _value => state.requireValue;

  Future<void> _advance({
    required FirstPrayerAnswers answers,
    required FirstPrayerStage stage,
  }) {
    _emit(AppFeedbackIntent.selection);
    return _saveProgress(
      _value.progress.copyWith(stage: stage, answers: answers),
    );
  }

  Future<void> _saveProgress(FirstPrayerProgress progress) async {
    state = AsyncData(_value.copyWith(progress: progress));
    await _persist(progress);
  }

  Future<void> _persist(FirstPrayerProgress progress) async {
    try {
      final repository = await ref.read(
        firstPrayerProgressRepositoryProvider.future,
      );
      await repository.save(progress);
    } on Object {
      // Local persistence must not interrupt prayer.
    }
  }

  void _emit(AppFeedbackIntent intent) {
    final preferences =
        ref.read(appFeedbackPreferencesProvider).value ??
        AppFeedbackPreferences.defaults;
    unawaited(
      ref
          .read(appFeedbackServiceProvider)
          .emit(intent, preferences: preferences),
    );
  }

  Future<void> _showGenerated(PrayerGenerationRequest request) async {
    final result = FirstPrayerResult(
      title: request.draftTitle?.trim().isNotEmpty == true
          ? request.draftTitle!.trim()
          : 'Your prayer',
      body: request.draftBody!.trim(),
      action: request.draftAction,
      grounding: request.grounding,
      purpose: request.purpose,
      reference: PrayerReference.personal(request.id),
      requestId: request.id,
    );
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.prayer,
      requestId: request.id,
      selectedPrayerType: 'generated',
      selectedPrayerId: request.id,
    );
    state = AsyncData(_value.copyWith(progress: progress, result: result));
    await _persist(progress);
  }

  Future<void> _showLibrary(LibraryPrayer prayer) async {
    final result = _fromLibrary(prayer);
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.prayer,
      selectedPrayerType: 'library',
      selectedPrayerId: prayer.id,
    );
    state = AsyncData(_value.copyWith(progress: progress, result: result));
    await _persist(progress);
  }

  Future<FirstPrayerResult?> _restoreResult(
    FirstPrayerProgress progress,
  ) async {
    try {
      if ((progress.selectedPrayerType == 'library' ||
              progress.selectedPrayerType == 'prepared') &&
          progress.selectedPrayerId != null) {
        final repository = await ref.read(prayerRepositoryProvider.future);
        final prayer = await repository
            .watchPrayer(progress.selectedPrayerId!)
            .first;
        return prayer == null ? null : _fromLibrary(prayer);
      }
      if ((progress.selectedPrayerType == 'generated' ||
              progress.selectedPrayerType == null) &&
          progress.requestId != null) {
        final repository = await ref.read(
          prayerGenerationRepositoryProvider.future,
        );
        final request = await repository.watch(progress.requestId!).first;
        if (request?.draftBody != null) {
          return FirstPrayerResult(
            title: request!.draftTitle ?? 'Your prayer',
            body: request.draftBody!,
            action: request.draftAction,
            grounding: request.grounding,
            purpose: request.purpose,
            reference: PrayerReference.personal(request.id),
            requestId: request.id,
          );
        }
      }
      if (progress.selectedPrayerType == 'personal' &&
          progress.selectedPrayerId != null) {
        final repository = await ref.read(
          personalPrayerRepositoryProvider.future,
        );
        final prayer = await repository.watch(progress.selectedPrayerId!).first;
        if (prayer != null) {
          return FirstPrayerResult(
            title: prayer.title,
            body: prayer.body,
            action: prayer.action,
            grounding: prayer.grounding,
            purpose: prayer.purpose,
            reference: prayer.reference,
            requestId: progress.requestId,
            revisionId:
                progress.selectedPrayerRevisionId ?? prayer.currentRevisionId,
          );
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  void _retryPrayerRepository() {
    final repositoryState = ref.read(prayerRepositoryProvider);
    if (!repositoryState.hasError) return;
    if (ref.read(appDatabaseProvider).hasError) {
      ref.invalidate(appDatabaseProvider);
    }
    if (ref.read(localIdentityProvider).hasError) {
      ref.invalidate(localIdentityProvider);
    }
    ref.invalidate(prayerRepositoryProvider);
  }
}

FirstPrayerResult _fromLibrary(LibraryPrayer prayer) => FirstPrayerResult(
  title: prayer.title,
  body: prayer.body,
  action: prayer.action,
  grounding: prayer.grounding,
  purpose: prayer.purpose,
  reference: prayer.reference,
);

FirstPrayerResult _lastResortPrayer() => const FirstPrayerResult(
  title: 'For this day',
  body:
      'Father, keep me near you through this day. Give me the daily bread I need, a willing heart for your will, and patience with each person I meet. Help me choose faithful action, speak truth with kindness, and love my neighbor in the work before me. In Jesus\' name. Amen.',
  action:
      'Complete one needed task, then help one person without seeking notice.',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.daily,
  reference: PrayerReference.library('0198a100-0000-7000-8000-000000000001'),
);

String _memoryLabel(MemoryType type) => switch (type) {
  MemoryType.promise => 'Promise',
  MemoryType.lesson => 'Scripture or lesson',
  _ => 'Encounter',
};

String _memoryDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
