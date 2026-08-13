import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_spacing.dart';
import '../application/memory_audio_player.dart';
import '../domain/memory_audio.dart';
import '../providers/memory_audio_providers.dart';

class AudioPlaybackControl extends ConsumerStatefulWidget {
  const AudioPlaybackControl({
    required this.audio,
    this.compact = false,
    this.label = 'Voice recording',
    this.playLabel = 'Play',
    this.allowDelete = false,
    this.stopOnDispose = false,
    super.key,
  });

  final MemoryAudio audio;
  final bool compact;
  final String label;
  final String playLabel;
  final bool allowDelete;
  final bool stopOnDispose;

  @override
  ConsumerState<AudioPlaybackControl> createState() =>
      _AudioPlaybackControlState();
}

class _AudioPlaybackControlState extends ConsumerState<AudioPlaybackControl> {
  MemoryAudioPlaybackCoordinator? _coordinator;
  MemoryAudioPlaybackCoordinator? _preparedCoordinator;
  String? _preparedAudioId;
  Future<bool>? _preparation;
  bool _deleting = false;

  @override
  void didUpdateWidget(covariant AudioPlaybackControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio.id != widget.audio.id) {
      _preparedCoordinator = null;
      _preparedAudioId = null;
      _preparation = null;
    }
  }

  @override
  void dispose() {
    final coordinator = _coordinator;
    if (widget.stopOnDispose && coordinator?.state.assetId == widget.audio.id) {
      unawaited(coordinator!.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinatorAsync = ref.watch(memoryAudioPlaybackCoordinatorProvider);
    return coordinatorAsync.when(
      loading: () => _loadingControl(),
      error: (_, _) =>
          Text('${widget.label} · ${_durationLabel(widget.audio.duration)}'),
      data: (coordinator) {
        _coordinator = coordinator;
        final preparation = _prepare(coordinator);
        return FutureBuilder<bool>(
          future: preparation,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _loadingControl();
            }
            if (snapshot.data != true) {
              return Text(
                '${widget.label} · This audio is not available on this device.',
              );
            }
            return AnimatedBuilder(
              animation: coordinator,
              builder: (context, _) => widget.compact
                  ? _compactControl(coordinator)
                  : _fullControl(coordinator),
            );
          },
        );
      },
    );
  }

  Future<bool> _prepare(MemoryAudioPlaybackCoordinator coordinator) {
    if (_preparedCoordinator != coordinator ||
        _preparedAudioId != widget.audio.id) {
      _preparedCoordinator = coordinator;
      _preparedAudioId = widget.audio.id;
      _preparation = coordinator.prepare(widget.audio);
    }
    return _preparation!;
  }

  Widget _loadingControl() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(
          '${widget.label} · ${_durationLabel(widget.audio.duration)}',
        ),
      ),
    ],
  );

  Widget _compactControl(MemoryAudioPlaybackCoordinator coordinator) {
    final state = coordinator.state;
    final active = state.assetId == widget.audio.id;
    final playing = active && state.status == MemoryAudioPlaybackStatus.playing;
    final busy = active && state.status == MemoryAudioPlaybackStatus.loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label),
                  Text(
                    _durationLabel(widget.audio.duration),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => playing
                          ? coordinator.pause()
                          : coordinator.play(widget.audio),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(playing ? Icons.pause : Icons.play_arrow),
                label: Text(playing ? 'Pause' : widget.playLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fullControl(MemoryAudioPlaybackCoordinator coordinator) {
    final state = coordinator.state;
    final active = state.assetId == widget.audio.id;
    final status = active ? state.status : MemoryAudioPlaybackStatus.idle;
    final position = active ? state.position : Duration.zero;
    final duration = active && state.duration > Duration.zero
        ? state.duration
        : widget.audio.duration;
    final playing = status == MemoryAudioPlaybackStatus.playing;
    final busy = status == MemoryAudioPlaybackStatus.loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text('Audio saved on this device'),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label:
                  '${_spokenDuration(position)} of ${_spokenDuration(duration)}',
              child: Slider(
                value: position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble(),
                max: duration.inMilliseconds.toDouble(),
                onChanged: active && !busy
                    ? (value) => coordinator.seek(
                        Duration(milliseconds: value.round()),
                      )
                    : null,
              ),
            ),
            Text(
              '${_durationLabel(position)} / ${_durationLabel(duration)}',
              textAlign: TextAlign.center,
            ),
            if (active && state.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(state.error!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => playing
                              ? coordinator.pause()
                              : coordinator.play(widget.audio),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(playing ? Icons.pause : Icons.play_arrow),
                    label: Text(playing ? 'Pause' : widget.playLabel),
                  ),
                ),
                if (active && status != MemoryAudioPlaybackStatus.idle)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : coordinator.stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  ),
                if (widget.allowDelete)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: TextButton.icon(
                      onPressed: _deleting ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(_deleting ? 'Deleting…' : 'Delete audio'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this audio?'),
        content: const Text(
          'This audio cannot be recovered from SoulBuddy. The written memory will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep audio'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove audio'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final coordinator = _coordinator;
      if (coordinator?.state.assetId == widget.audio.id) {
        await coordinator!.stop();
      }
      final deletion = await ref.read(memoryAudioDeletionProvider.future);
      await deletion.deleteForEncounter(widget.audio.encounterId);
      ref.invalidate(memoryAudioForEncounterProvider(widget.audio.encounterId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The audio could not be removed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

String _durationLabel(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _spokenDuration(Duration value) =>
    '${value.inMinutes} minutes ${value.inSeconds % 60} seconds';
