import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../record/audio/data/audio_asset_store.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/presentation/audio_capture_panel.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../data/voice_tablet_repository.dart';
import '../domain/voice_tablet.dart';
import '../providers/voice_tablet_providers.dart';

enum VoiceTabletSheetStep { fullPrayer, refrainChoice, refrain, saving }

class VoiceTabletSheet extends ConsumerStatefulWidget {
  const VoiceTabletSheet({
    required this.source,
    required this.title,
    required this.prayerBody,
    this.initialFullDraft,
    super.key,
  });

  final VoiceTabletSource source;
  final String title;
  final String prayerBody;
  final RecordedAudioDraft? initialFullDraft;

  @override
  ConsumerState<VoiceTabletSheet> createState() => _VoiceTabletSheetState();
}

class _VoiceTabletSheetState extends ConsumerState<VoiceTabletSheet> {
  late VoiceTabletSheetStep _step;
  RecordedAudioDraft? _fullDraft;
  RecordedAudioDraft? _refrainDraft;
  VoiceTabletAudioAttachment? _fullAttachment;
  VoiceTabletAudioAttachment? _refrainAttachment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fullDraft = widget.initialFullDraft;
    _step = widget.initialFullDraft == null
        ? VoiceTabletSheetStep.fullPrayer
        : VoiceTabletSheetStep.refrainChoice;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.94;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              _SheetHeader(onClose: _close),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() => switch (_step) {
    VoiceTabletSheetStep.fullPrayer => _capture(
      kind: VoiceTabletAudioKind.fullPrayer,
      heading: 'Record this prayer',
      description:
          'Read it in your own voice. The recording stays on this device.',
      startLabel: 'Begin recording',
      onContinue: (draft) => setState(() {
        _fullDraft = draft;
        _error = null;
        _step = VoiceTabletSheetStep.refrainChoice;
      }),
    ),
    VoiceTabletSheetStep.refrainChoice => _RefrainChoice(
      prayerBody: widget.prayerBody,
      error: _error,
      onAdd: () => setState(() {
        _error = null;
        _step = VoiceTabletSheetStep.refrain;
      }),
      onSave: _save,
      onBack: _recordFullPrayerAgain,
    ),
    VoiceTabletSheetStep.refrain => _capture(
      kind: VoiceTabletAudioKind.refrain,
      heading: 'Record a Prayer Refrain',
      description:
          'Choose one short line you can return to during the day. Up to 25 seconds.',
      startLabel: 'Record the refrain',
      onContinue: (draft) {
        setState(() {
          _refrainDraft = draft;
          _error = null;
        });
        _save();
      },
      onBack: () => setState(() {
        _error = null;
        _step = VoiceTabletSheetStep.refrainChoice;
      }),
    ),
    VoiceTabletSheetStep.saving => const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Saving on this device…'),
        ],
      ),
    ),
  };

  Widget _capture({
    required VoiceTabletAudioKind kind,
    required String heading,
    required String description,
    required String startLabel,
    required ValueChanged<RecordedAudioDraft> onContinue,
    VoidCallback? onBack,
  }) {
    final controller = ref.watch(
      voiceTabletAudioCaptureControllerProvider(kind),
    );
    return controller.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _SheetMessage(
        message: 'The microphone could not be prepared just now.',
        actionLabel: 'Close',
        onAction: _close,
      ),
      data: (value) => AudioCapturePanel(
        controller: value,
        introHeading: heading,
        introDescription: description,
        introContent: PrayerTextSlab(text: widget.prayerBody),
        startLabel: startLabel,
        alternativeLabel: 'Not now',
        onWriteInstead: _close,
        onContinue: onContinue,
        onBack: onBack,
      ),
    );
  }

  Future<void> _save() async {
    final fullDraft = _fullDraft;
    if (fullDraft == null || _step == VoiceTabletSheetStep.saving) return;
    final previousStep = _refrainDraft == null
        ? VoiceTabletSheetStep.refrainChoice
        : VoiceTabletSheetStep.refrain;
    setState(() {
      _error = null;
      _step = VoiceTabletSheetStep.saving;
    });
    try {
      final store = await ref.read(audioAssetStoreProvider.future);
      _fullAttachment ??= await _commit(
        store,
        fullDraft,
        VoiceTabletAudioKind.fullPrayer,
      );
      if (_refrainDraft case final refrain?) {
        _refrainAttachment ??= await _commit(
          store,
          refrain,
          VoiceTabletAudioKind.refrain,
        );
      }
      final repository = await ref.read(voiceTabletRepositoryProvider.future);
      final tablet = await repository.create(
        VoiceTabletCreateRequest(
          source: widget.source,
          title: widget.title,
          fullRecording: _fullAttachment!,
          refrain: _refrainAttachment,
        ),
      );
      if (mounted) Navigator.pop(context, tablet);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = previousStep;
        _error =
            'The Voice Tablet was not saved. Your prepared recording is still on this device; try again.';
      });
    }
  }

  Future<VoiceTabletAudioAttachment> _commit(
    AudioAssetStore store,
    RecordedAudioDraft draft,
    VoiceTabletAudioKind kind,
  ) async {
    final id = const Uuid().v7();
    final committed = await store.commitTemporary(
      TemporaryAudio(key: draft.temporaryKey, locator: draft.temporaryKey),
      assetId: id,
      mimeType: draft.mimeType,
    );
    return VoiceTabletAudioAttachment(
      id: id,
      kind: kind,
      draft: draft,
      committed: committed,
    );
  }

  Future<void> _close() async {
    if (_step == VoiceTabletSheetStep.saving) return;
    final kind = _step == VoiceTabletSheetStep.refrain
        ? VoiceTabletAudioKind.refrain
        : VoiceTabletAudioKind.fullPrayer;
    final controller = ref.read(
      voiceTabletAudioCaptureControllerProvider(kind),
    );
    if (controller.hasValue) await controller.requireValue.handleInterruption();
    await _discardUncommittedDrafts();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _recordFullPrayerAgain() async {
    final draft = _fullDraft;
    if (draft != null && _fullAttachment == null) {
      final store = await ref.read(audioAssetStoreProvider.future);
      try {
        await store.discardTemporary(draft.temporaryKey);
      } catch (_) {
        // Startup orphan cleanup retries without exposing the private key.
      }
    }
    if (!mounted) return;
    setState(() {
      _fullDraft = null;
      _error = null;
      _step = VoiceTabletSheetStep.fullPrayer;
    });
  }

  Future<void> _discardUncommittedDrafts() async {
    final keys = <String>{
      if (_fullAttachment == null && _fullDraft != null)
        _fullDraft!.temporaryKey,
      if (_refrainAttachment == null && _refrainDraft != null)
        _refrainDraft!.temporaryKey,
    };
    if (keys.isEmpty) return;
    final store = await ref.read(audioAssetStoreProvider.future);
    for (final key in keys) {
      try {
        await store.discardTemporary(key);
      } catch (_) {
        // Startup orphan cleanup retries without exposing the private key.
      }
    }
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.sm,
      0,
    ),
    child: Row(
      children: [
        const CovenantPairedSlabMark(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Voice Tablet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _RefrainChoice extends StatelessWidget {
  const _RefrainChoice({
    required this.prayerBody,
    required this.error,
    required this.onAdd,
    required this.onSave,
    required this.onBack,
  });

  final String prayerBody;
  final String? error;
  final VoidCallback onAdd;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Record again'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your prayer is recorded',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('You may also keep one short line as a Prayer Refrain.'),
            const SizedBox(height: AppSpacing.md),
            PrayerTextSlab(text: prayerBody),
            if (error case final message?) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.graphic_eq),
              label: const Text('Add a short refrain'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
              ),
              onPressed: onSave,
              child: const Text('Save without a refrain'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PrayerTextSlab extends StatelessWidget {
  const PrayerTextSlab({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipPath(
      clipper: const _NaturalSlabClipper(),
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CovenantIncisedDivider(height: 12),
              const SizedBox(height: AppSpacing.sm),
              Text(
                text,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NaturalSlabClipper extends CustomClipper<Path> {
  const _NaturalSlabClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(5, 3)
    ..lineTo(size.width * 0.37, 0)
    ..lineTo(size.width - 4, 4)
    ..lineTo(size.width, size.height * 0.43)
    ..lineTo(size.width - 3, size.height - 5)
    ..lineTo(size.width * 0.58, size.height)
    ..lineTo(4, size.height - 3)
    ..lineTo(0, size.height * 0.34)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

Future<VoiceTablet?> showVoiceTabletSheet(
  BuildContext context, {
  required VoiceTabletSource source,
  required String title,
  required String prayerBody,
}) => showModalBottomSheet<VoiceTablet>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  useSafeArea: true,
  builder: (_) =>
      VoiceTabletSheet(source: source, title: title, prayerBody: prayerBody),
);
