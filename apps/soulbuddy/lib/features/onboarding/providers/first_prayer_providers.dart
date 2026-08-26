import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/prayer_generation_request.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../record/audio/domain/memory_audio.dart';
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
  });

  final FirstPrayerProgress progress;
  final FirstPrayerResult? result;
  final bool detailByVoice;
  final MemoryType? remembranceType;
  final bool remembranceByVoice;

  FirstPrayerState copyWith({
    FirstPrayerProgress? progress,
    FirstPrayerResult? result,
    bool clearResult = false,
    bool? detailByVoice,
    MemoryType? remembranceType,
    bool? remembranceByVoice,
  }) => FirstPrayerState(
    progress: progress ?? this.progress,
    result: clearResult ? null : result ?? this.result,
    detailByVoice: detailByVoice ?? this.detailByVoice,
    remembranceType: remembranceType ?? this.remembranceType,
    remembranceByVoice: remembranceByVoice ?? this.remembranceByVoice,
  );
}

class FirstPrayerController extends AsyncNotifier<FirstPrayerState> {
  @override
  Future<FirstPrayerState> build() async {
    final progressRepository = await ref.watch(
      firstPrayerProgressRepositoryProvider.future,
    );
    var progress =
        await progressRepository.load() ?? const FirstPrayerProgress();
    if (progress.stage.index > FirstPrayerStage.remembranceType.index) {
      progress = progress.copyWith(stage: FirstPrayerStage.remembranceType);
    }
    final result = await _restoreResult(progress);
    return FirstPrayerState(progress: progress, result: result);
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
    final progress = _value.progress.copyWith(stage: FirstPrayerStage.detail);
    state = AsyncData(
      _value.copyWith(progress: progress, detailByVoice: speak),
    );
    await _persist(progress);
  }

  Future<void> prepare({String? detail}) async {
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
      final completed = await generationRepository.watch(request.id).first;
      if (completed?.status == PrayerGenerationStatus.ready &&
          completed?.draftBody?.trim().isNotEmpty == true) {
        await _showGenerated(completed!);
        return;
      }
    } on Object {
      // A prepared prayer is always the quiet offline path.
    }
    await usePreparedPrayer();
  }

  Future<void> usePreparedPrayer() async {
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
    }
    final fallback = _lastResortPrayer(_value.progress.answers);
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

  Future<void> keepPrayer({required bool recordPractice}) async {
    var result = _value.result;
    if (result == null) return;
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
      // A failed local write must not keep someone from continuing in prayer.
    }
    final progress = _value.progress.copyWith(stage: FirstPrayerStage.practice);
    state = AsyncData(_value.copyWith(progress: progress, result: result));
    _emit(
      recordPractice
          ? AppFeedbackIntent.prayerCompleted
          : AppFeedbackIntent.saved,
    );
    await _persist(progress);
  }

  Future<void> continueFromPractice() => _saveProgress(
    _value.progress.copyWith(stage: FirstPrayerStage.remembranceType),
  );

  Future<void> chooseRemembranceType(MemoryType type) async {
    _emit(AppFeedbackIntent.selection);
    final progress = _value.progress.copyWith(
      stage: FirstPrayerStage.remembranceMode,
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
    );
    state = AsyncData(
      _value.copyWith(progress: progress, remembranceByVoice: speak),
    );
    await _persist(progress);
  }

  Future<void> saveRemembrance({
    String body = '',
    MemoryAudioDraft? audio,
  }) async {
    final type = _value.remembranceType;
    if (type == null) return;
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
          audio: audio,
        ),
      );
      ref.invalidate(encountersProvider);
      _emit(AppFeedbackIntent.saved);
    } on Object {
      // Completion remains available even if a local write needs later retry.
    }
    await complete();
  }

  Future<void> complete() async {
    try {
      final repository = await ref.read(
        firstPrayerProgressRepositoryProvider.future,
      );
      await repository.clear();
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
    if (progress.stage != FirstPrayerStage.prayer) return null;
    try {
      if (progress.selectedPrayerType == 'library' &&
          progress.selectedPrayerId != null) {
        final repository = await ref.read(prayerRepositoryProvider.future);
        final prayer = await repository
            .watchPrayer(progress.selectedPrayerId!)
            .first;
        return prayer == null ? null : _fromLibrary(prayer);
      }
      if (progress.selectedPrayerType == 'generated' &&
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
    } on Object {
      return null;
    }
    return null;
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

FirstPrayerResult _lastResortPrayer(FirstPrayerAnswers answers) {
  final body = switch (answers.purpose) {
    FirstPrayerPurpose.guidance =>
      'Father, guide me in your truth. Give me wisdom for what is before me, and grace to obey what you show me. Keep me close to Jesus. Amen.',
    FirstPrayerPurpose.family =>
      'Father, keep my family in your care. Teach us to love, forgive, and serve one another. Let your peace dwell among us. Amen.',
    FirstPrayerPurpose.healing =>
      'Lord Jesus, have mercy on me. Bring healing according to your will, give strength for today, and keep my hope in you. Amen.',
    FirstPrayerPurpose.forgiveness =>
      'Father, forgive me and make my heart clean. Help me receive your mercy and extend mercy to others. Lead me in the way of Jesus. Amen.',
    FirstPrayerPurpose.difficultTime =>
      'Father, remain with me in this difficult time. Give me courage, patience, and faith for what I must carry today. Amen.',
    _ =>
      'Father, keep me close to you today. Teach me to hear your word, obey you with love, and walk in the way of Jesus. Amen.',
  };
  return FirstPrayerResult(
    title: answers.purpose?.label ?? 'Stay close',
    body: body,
    action: 'Return to this prayer before the day ends.',
    grounding: answers.grounding,
    purpose: answers.prayerPurpose,
    reference: const PrayerReference.library('guided-offline'),
  );
}

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
