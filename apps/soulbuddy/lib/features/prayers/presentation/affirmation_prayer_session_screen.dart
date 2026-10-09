import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/presentation/screen_awake.dart';
import '../application/affirmation_prayer_audio.dart';
import '../application/affirmation_prayer_session_controller.dart';
import '../application/meditation_sound_preferences.dart';
import '../data/prayer_release_repository.dart';
import '../domain/affirmation_prayer.dart';
import '../domain/meditation_session.dart';
import '../domain/worship_sound_bed.dart';
import '../providers/prayer_release_providers.dart';

/// A counted Prayer of attention for the release item that carries the
/// repetition practice profile.
///
/// This is not a meditation timer and not a gamified counter. The prayer's exact
/// words lead; the count is a quiet support for faithful repetition.
class AffirmationPrayerSessionScreen extends ConsumerStatefulWidget {
  const AffirmationPrayerSessionScreen({
    required this.profile,
    required this.releaseItemId,
    required this.libraryPrayerId,
    required this.sessionId,
    this.narration,
    this.soundBed,
    this.awake,
    this.now,
    this.soundPreferences,
    super.key,
  });

  final AffirmationPrayerProfile profile;

  /// The release item that carries the practice profile.
  final String releaseItemId;

  /// The canonical prayer this item points at, used to resolve its narration.
  final String libraryPrayerId;

  final String sessionId;

  /// Injected for tests; the app supplies the platform seams.
  final AffirmationPrayerNarrationPlayer? narration;
  final AffirmationPrayerSoundBed? soundBed;
  final AffirmationPrayerScreenAwake? awake;
  final DateTime Function()? now;

  /// The saved meditation sound preference. Defaults to the shared repository.
  final MeditationSoundPreferencesRepository? soundPreferences;

  @override
  ConsumerState<AffirmationPrayerSessionScreen> createState() =>
      _AffirmationPrayerSessionScreenState();
}

class _AffirmationPrayerSessionScreenState
    extends ConsumerState<AffirmationPrayerSessionScreen> {
  late final AffirmationPrayerSessionController _session;

  @override
  void initState() {
    super.initState();
    _session = AffirmationPrayerSessionController(
      profile: widget.profile,
      releaseItemId: widget.releaseItemId,
      sessionId: widget.sessionId,
      narration:
          widget.narration ?? AffirmationPrayerVoice(speakPhrase: _speakPhrase),
      soundBed: widget.soundBed ?? AffirmationPrayerBedPlayer(),
      awake:
          widget.awake ??
          AffirmationPrayerAwake(ScreenAwakeController.shared, this),
      saveSession: _repository,
      now: widget.now,
    );
    unawaited(_restoreSoundPreference());
  }

  /// Speaks the exact phrase the person can see.
  ///
  /// Audio is used only when the server validated a recorded transcript against
  /// this item's content hash. Otherwise nothing is spoken, so no substitute
  /// script is ever read.
  Future<void> _speakPhrase(String phrase, double speed) async {
    final voice = _session.narration;
    if (voice is! AffirmationPrayerVoice) return;

    try {
      final repository = await ref.read(prayerReleaseRepositoryProvider.future);
      final item = await repository
          .watchContentForPrayer(widget.libraryPrayerId)
          .first;
      if (item?.itemId == null) return;

      final narration = await ref
          .read(prayerReleaseNarrationRepositoryProvider)
          .load(item!.itemId!);
      if (narration == null) return;

      final bytes = await ref
          .read(prayerReleaseNarrationRepositoryProvider)
          .bytes(narration);
      await voice.playAsset(bytes, speed: speed);
    } catch (_) {
      // Spoken guidance is optional; the prayer continues in silence.
    }
  }

  AffirmationPrayerSessionRepository _repository() {
    return _LocalSessionRepository(
      ref.read(prayerReleaseRepositoryProvider.future),
    );
  }

  /// Applies the saved prayer sound preference, if it is one this flow offers.
  /// Nothing here starts sound.
  ///
  /// Worship is restored only from its own slot. It is never read back out of
  /// the shared ambient slot, so a worship choice made here cannot reach any
  /// surface that offers `MeditationSoundPicker`.
  Future<void> _restoreSoundPreference() async {
    try {
      final preferences = await _soundPreferences().load();
      final worship = preferences.worship;
      if (worship != null) {
        await _session.setSound(
          soundKey: worship.sound.key,
          volume: worship.volume,
        );
        return;
      }
      final bed = preferences.sound;
      if (bed == null || !_allowed(bed)) return;
      await _session.setSound(soundKey: bed.key, volume: preferences.volume);
    } catch (_) {
      // A preference that cannot be read simply leaves the silence default.
    }
  }

  bool _allowed(MeditationSoundBed bed) {
    return AffirmationPrayerSoundFamily.values.any(
      (family) => family.sounds.contains(bed),
    );
  }

  MeditationSoundPreferencesRepository _soundPreferences() =>
      widget.soundPreferences ?? ref.read(meditationSoundPreferencesProvider);

  /// Saves the chosen bed to the slot that owns it, so the shared ambient slot
  /// is left exactly as the seven other surfaces expect to find it.
  Future<void> _saveSound(PrayerSoundBed? bed, double volume) async {
    await _session.setSound(soundKey: bed?.key, volume: volume);
    final preferences = await _soundPreferences().load();
    final next = preferences;
    if (bed is WorshipSoundBed) {
      await _soundPreferences().save(
        MeditationSoundPreferences(
          // The shared ambient choice is left exactly as it was: worship is
          // this practice's own, and writing it into the ambient slot would
          // hand a worship asset to the seven surfaces that read that slot.
          sound: next.sound,
          volume: next.volume,
          worship: WorshipSoundPreference(sound: bed, volume: volume),
        ),
      );
      return;
    }
    await _soundPreferences().save(
      MeditationSoundPreferences(
        sound: bed is MeditationSoundBed ? bed : null,
        volume: volume,
        worship: next.worship,
      ),
    );
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) => PracticeAudioScope(
        // Leaving, backgrounding, or losing focus stops sound at once.
        onVisibilityChanged: (visible) {
          if (visible) {
            _session.becameVisible();
          } else {
            unawaited(_session.pauseForInterruption());
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const Key('attention-prayer-close'),
              onPressed: () => _leave(context),
              icon: const Icon(Icons.close),
              tooltip: 'End',
            ),
            title: const Text('Prayer of attention'),
          ),
          body: SafeArea(child: _phase(context)),
        ),
      ),
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/prayers');
    }
  }

  Widget _phase(BuildContext context) {
    return switch (_session.state.phase) {
      AffirmationPrayerPhase.recollection => _RecollectionView(
        line: AffirmationPrayerWords
            .recollectionLines[_session.state.recollectionIndex],
        isLast:
            _session.state.recollectionIndex ==
            AffirmationPrayerWords.recollectionLines.length - 1,
        onAdvance: _session.advanceRecollection,
        onSkip: _session.skipRecollection,
      ),
      AffirmationPrayerPhase.setup => _SetupView(
        session: _session,
        started: _session.state.started,
        onBegin: _session.begin,
        onResume: _session.resume,
        onSoundChanged: _saveSound,
      ),
      AffirmationPrayerPhase.praying => _PrayingView(
        session: _session,
        onEnd: _session.end,
        onPause: _session.pause,
      ),
      AffirmationPrayerPhase.groupPause => _GroupPauseView(
        session: _session,
        onResume: _session.leaveGroupPause,
      ),
      AffirmationPrayerPhase.completed => _CompletionView(
        session: _session,
        onPray: () => context.go('/today'),
        onReflect: () => context.go('/remember/capture'),
        onScripture: () => context.go('/scripture/daily'),
        onChooseForToday: () => context.go('/prayers'),
      ),
    };
  }
}

/// The skippable guided recollection. Each line fades in and out, and no sound
/// starts here.
class _RecollectionView extends StatelessWidget {
  const _RecollectionView({
    required this.line,
    required this.isLast,
    required this.onAdvance,
    required this.onSkip,
  });

  final String line;
  final bool isLast;
  final VoidCallback onAdvance;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(
          AffirmationPrayerWords.entry,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AnimatedOpacity(
          key: const Key('attention-prayer-recollection-line'),
          opacity: 1,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 400),
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            TextButton(
              key: const Key('attention-prayer-skip'),
              onPressed: onSkip,
              child: const Text('Skip'),
            ),
            FilledButton(
              key: const Key('attention-prayer-advance-recollection'),
              onPressed: onAdvance,
              child: Text(isLast ? 'Be still' : 'Next'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Deliberately short setup: sound, level, guide, and pace.
class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.session,
    required this.started,
    required this.onBegin,
    required this.onResume,
    required this.onSoundChanged,
  });

  final AffirmationPrayerSessionController session;
  final bool started;
  final Future<void> Function() onBegin;
  final Future<void> Function() onResume;
  final Future<void> Function(PrayerSoundBed? bed, double volume)
  onSoundChanged;

  @override
  Widget build(BuildContext context) {
    final state = session.state;
    final theme = Theme.of(context);
    var selected = state.soundKey == null
        ? null
        : AffirmationPrayerSoundFamily.values
              .expand((family) => family.sounds)
              .where((bed) => bed.key == state.soundKey)
              .firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(AffirmationPrayerWords.setup, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Creation sounds for quiet attention. '
          'Quiet instrumental and worship music.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final family in AffirmationPrayerSoundFamily.values) ...[
          Text(family.label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final bed in family.sounds)
                ChoiceChip(
                  key: Key('attention-prayer-sound-${bed.key}'),
                  label: Text(bed.label),
                  selected: selected == bed,
                  onSelected: (_) => onSoundChanged(
                    bed,
                    family.levelFor(bed, state.soundVolume),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text('Sound level', style: theme.textTheme.labelLarge),
        Slider(
          key: const Key('attention-prayer-volume'),
          value: state.soundVolume.clamp(.05, .3),
          min: .05,
          max: .3,
          divisions: 5,
          label: '${(state.soundVolume * 100).round()}%',
          onChanged: (value) => unawaited(onSoundChanged(selected, value)),
        ),
        SwitchListTile(
          key: const Key('attention-prayer-guide'),
          value: state.guideEnabled,
          onChanged: (value) => unawaited(session.setGuideEnabled(value)),
          title: const Text('Speak the words'),
          subtitle: const Text('Exact words at the chosen pace.'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Voice speed', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final speed
                in AffirmationPrayerSessionController.availableSpeeds)
              ChoiceChip(
                key: Key('attention-prayer-speed-$speed'),
                label: Text('${speed}x'),
                selected: (state.speed - speed).abs() < 0.001,
                onSelected: (_) => unawaited(session.setSpeed(speed)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          key: const Key('attention-prayer-begin'),
          onPressed: started ? onResume : onBegin,
          child: Text(started ? AffirmationPrayerWords.resume : 'Begin prayer'),
        ),
        if (started) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('attention-prayer-end-setup'),
            onPressed: session.end,
            child: const Text(AffirmationPrayerWords.end),
          ),
        ],
      ],
    );
  }
}

/// One exact phrase at the center, with the count quietly below it.
class _PrayingView extends StatelessWidget {
  const _PrayingView({
    required this.session,
    required this.onEnd,
    required this.onPause,
  });

  final AffirmationPrayerSessionController session;
  final Future<void> Function() onEnd;
  final Future<void> Function() onPause;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final state = session.state;

    // A scroll view keeps the phrase, the count, and the controls reachable at
    // any system font scale.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          AffirmationPrayerWords.beforeRepetition,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Warm low-contrast gold light from above, with a restrained glow that
        // respects reduced motion and never competes with the words.
        AnimatedOpacity(
          opacity: .92,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 600),
          child: Text(
            session.currentPhrase,
            key: const Key('attention-prayer-phrase'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF8A6A32),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // The count is a support for the prayer, not a score.
        Text(
          session.countLabel,
          key: const Key('attention-prayer-count'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          key: const Key('attention-prayer-continue'),
          onPressed: session.confirmSpoken,
          child: const Text(AffirmationPrayerWords.advance),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton(
              key: const Key('attention-prayer-hear-again'),
              onPressed: session.hearAgain,
              child: const Text(AffirmationPrayerWords.hearAgain),
            ),
            TextButton(
              key: const Key('attention-prayer-pause'),
              onPressed: onPause,
              child: const Text(AffirmationPrayerWords.pause),
            ),
            TextButton(
              key: const Key('attention-prayer-end'),
              onPressed: onEnd,
              child: const Text(AffirmationPrayerWords.end),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: _CountRing(
            count: state.count,
            target: state.target,
            reduceMotion: reduceMotion,
          ),
        ),
      ],
    );
  }
}

/// A small ring that fills with each deliberate confirmation. It never pulses,
/// celebrates, or presents a score.
class _CountRing extends StatelessWidget {
  const _CountRing({
    required this.count,
    required this.target,
    required this.reduceMotion,
  });

  final int count;
  final int target;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);

    return SizedBox.square(
      dimension: 44,
      child: TweenAnimationBuilder<double>(
        key: const Key('attention-prayer-count-ring'),
        tween: Tween(end: progress),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
        builder: (context, value, _) => CircularProgressIndicator(
          value: value,
          strokeWidth: 2,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: .12),
        ),
      ),
    );
  }
}

/// An untimed focused pause between groups of ten.
class _GroupPauseView extends StatelessWidget {
  const _GroupPauseView({required this.session, required this.onResume});

  final AffirmationPrayerSessionController session;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(
          AffirmationPrayerWords.groupPause,
          key: const Key('attention-prayer-group-pause'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          session.countLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          key: const Key('attention-prayer-group-resume'),
          onPressed: onResume,
          child: const Text(AffirmationPrayerWords.advance),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('attention-prayer-group-end'),
          onPressed: session.end,
          child: const Text(AffirmationPrayerWords.end),
        ),
      ],
    );
  }
}

/// Completion leads with one quiet line, then optional responses.
class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.session,
    required this.onPray,
    required this.onReflect,
    required this.onScripture,
    required this.onChooseForToday,
  });

  final AffirmationPrayerSessionController session;
  final VoidCallback onPray;
  final VoidCallback onReflect;
  final VoidCallback onScripture;
  final VoidCallback onChooseForToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = session.state;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(
          AffirmationPrayerWords.completion,
          key: const Key('attention-prayer-completion'),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          state.saved
              ? 'Prayer session saved.'
              : 'Prayer session complete.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (state.saveFailed) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('attention-prayer-save-retry'),
            onPressed: session.retrySave,
            child: const Text('Try again'),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              key: const Key('attention-prayer-after-pray'),
              onPressed: onPray,
              child: const Text(AffirmationPrayerWords.pray),
            ),
            OutlinedButton(
              key: const Key('attention-prayer-after-reflect'),
              onPressed: onReflect,
              child: const Text(AffirmationPrayerWords.reflect),
            ),
            OutlinedButton(
              key: const Key('attention-prayer-after-scripture'),
              onPressed: onScripture,
              child: const Text(AffirmationPrayerWords.scripture),
            ),
            OutlinedButton(
              key: const Key('attention-prayer-after-choose'),
              onPressed: onChooseForToday,
              child: const Text(AffirmationPrayerWords.chooseForToday),
            ),
          ],
        ),
      ],
    );
  }
}

/// Saves the terminal record once, through the release repository.
class _LocalSessionRepository implements AffirmationPrayerSessionRepository {
  _LocalSessionRepository(this._repository);

  final Future<PrayerReleaseRepository> _repository;

  @override
  Future<void> save(AffirmationPrayerSession session) async {
    final repository = await _repository;
    await repository.saveAffirmationSession(session);
  }
}
