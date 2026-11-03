import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/audio_capture_controller.dart';
import '../application/recording_activity.dart';
import '../domain/memory_audio.dart';
import '../providers/memory_audio_providers.dart';
import 'audio_capture_panel.dart';

class InlineAudioCapture extends ConsumerStatefulWidget {
  const InlineAudioCapture({
    required this.onSave,
    this.beforeStart,
    this.onBusyChanged,
    this.onDiscarded,
    this.contextIdentity,
    this.enableSoundscape = false,
    this.autoStart = false,
    this.enabled = true,
    this.label = 'Record',
    this.saveLabel = 'Save',
    this.buttonKey,
    this.draftSavedElsewhere = false,
    super.key,
  });
  final Future<void> Function(RecordedAudioDraft draft) onSave;
  final Future<void> Function()? beforeStart;
  final ValueChanged<bool>? onBusyChanged;
  final VoidCallback? onDiscarded;
  final Object? contextIdentity;
  final bool enableSoundscape;
  final bool autoStart;
  final bool enabled;
  final String label;
  final String saveLabel;
  final Key? buttonKey;
  final bool draftSavedElsewhere;

  @override
  ConsumerState<InlineAudioCapture> createState() => _InlineAudioCaptureState();
}

class _InlineAudioCaptureState extends ConsumerState<InlineAudioCapture>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<InlineAudioCapture> {
  @override
  bool get wantKeepAlive => true;
  final Object _key = Object();
  bool _open = false;
  bool _starting = false;
  bool _saving = false;
  String? _error;
  RecordedAudioDraft? _draft;
  ProviderSubscription<AsyncValue<AudioCaptureController>>? _subscription;
  bool _foreground = true;
  late final RecordingActivity _activity;

  @override
  void initState() {
    super.initState();
    _activity = ref.read(recordingActivityProvider);
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_start());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      final controller = _subscription?.read().value;
      if (controller != null) unawaited(controller.handleInterruption());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activity.end(_key);
    _subscription?.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InlineAudioCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextIdentity != widget.contextIdentity && !_open) {
      _error = null;
    }
  }

  Future<void> _start() async {
    if (_starting || !widget.enabled) return;
    if (!_activity.begin(_key)) {
      setState(() => _error = 'Finish the current recording first.');
      return;
    }
    setState(() {
      _starting = true;
      _open = true;
      _error = null;
    });
    final busyChanged = widget.onBusyChanged;
    final identity = widget.contextIdentity;
    _subscription ??= ref.listenManual(
      inlineAudioCaptureControllerProvider(_key),
      (_, _) {},
      fireImmediately: true,
    );
    busyChanged?.call(true);
    try {
      await widget.beforeStart?.call();
      final controller = await ref.read(
        inlineAudioCaptureControllerProvider(_key).future,
      );
      if (!mounted) return;
      await controller.start();
      if (!_foreground) await controller.handleInterruption();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = identity == widget.contextIdentity
              ? 'Recording unavailable'
              : null;
          _open = false;
        });
      }
      if (mounted) busyChanged?.call(false);
      _activity.end(_key);
      _subscription?.close();
      _subscription = null;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _save(RecordedAudioDraft draft) async {
    setState(() {
      _draft = draft;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(draft);
      if (!mounted) return;
      setState(() {
        _draft = null;
        _open = false;
      });
      _subscription?.close();
      _subscription = null;
      _activity.end(_key);
      widget.onBusyChanged?.call(false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Save failed. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardDraft() async {
    final draft = _draft;
    if (draft == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.draftSavedElsewhere
              ? 'Keep prayer without adding it?'
              : 'Discard recording?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.draftSavedElsewhere ? 'Cancel' : 'Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.draftSavedElsewhere ? 'Keep prayer' : 'Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final store = await ref.read(audioAssetStoreProvider.future);
      await store.discardTemporary(draft.temporaryKey);
      if (!mounted) return;
      setState(() {
        _draft = null;
        _open = false;
        _error = null;
      });
      _subscription?.close();
      _subscription = null;
      _activity.end(_key);
      widget.onDiscarded?.call();
      widget.onBusyChanged?.call(false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Discard failed. Try again.');
    }
  }

  void _closeEmpty() {
    setState(() {
      _open = false;
      _error = null;
    });
    _subscription?.close();
    _subscription = null;
    _activity.end(_key);
    widget.onBusyChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_open) return;
        final controller = ref
            .read(inlineAudioCaptureControllerProvider(_key))
            .value;
        if (!_starting &&
            _draft == null &&
            (controller == null ||
                (!controller.hasPendingRecording &&
                    !controller.state.commandInFlight))) {
          _closeEmpty();
          return;
        }
        if (controller != null) unawaited(controller.handleInterruption());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save or discard the recording.')),
        );
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!_open) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) Text(_error!),
          OutlinedButton.icon(
            key: widget.buttonKey,
            onPressed: widget.enabled ? _start : null,
            icon: const Icon(Icons.mic_none),
            label: Text(widget.label),
          ),
        ],
      );
    }
    if (_draft case final draft?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) Text(_error!),
          if (_saving)
            const CircularProgressIndicator()
          else ...[
            FilledButton(
              onPressed: () => _save(draft),
              child: const Text('Retry save'),
            ),
            TextButton(
              onPressed: _discardDraft,
              child: Text(
                widget.draftSavedElsewhere ? 'Keep prayer' : 'Discard',
              ),
            ),
          ],
        ],
      );
    }
    final capture = ref.watch(inlineAudioCaptureControllerProvider(_key));
    return capture.when(
      loading: () => const CircularProgressIndicator(),
      error: (_, _) => Column(
        children: [
          TextButton(
            onPressed: () {
              ref.invalidate(inlineAudioCaptureControllerProvider(_key));
              _start();
            },
            child: const Text('Try microphone again'),
          ),
          TextButton(onPressed: _closeEmpty, child: const Text('Cancel')),
        ],
      ),
      data: (controller) => _starting
          ? const CircularProgressIndicator()
          : AudioCapturePanel(
              controller: controller,
              inline: true,
              enableSoundscape: widget.enableSoundscape,
              onWriteInstead: _closeEmpty,
              alternativeLabel: 'Cancel',
              startLabel: widget.label,
              continueLabel: widget.saveLabel,
              onDiscarded: () {
                setState(() => _open = false);
                _subscription?.close();
                _subscription = null;
                _activity.end(_key);
                widget.onDiscarded?.call();
                widget.onBusyChanged?.call(false);
              },
              onContinue: (draft) => unawaited(_save(draft)),
            ),
    );
  }
}
