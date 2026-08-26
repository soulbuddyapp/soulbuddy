import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/design/app_spacing.dart';

final firstPrayerSpeechProvider = Provider<SpeechToText>((ref) {
  final speech = SpeechToText();
  ref.onDispose(() => unawaited(speech.cancel()));
  return speech;
});

class FirstPrayerSpeechPage extends ConsumerStatefulWidget {
  const FirstPrayerSpeechPage({
    required this.onContinue,
    required this.onWriteInstead,
    required this.onSkip,
    super.key,
  });

  final ValueChanged<String> onContinue;
  final VoidCallback onWriteInstead;
  final VoidCallback onSkip;

  @override
  ConsumerState<FirstPrayerSpeechPage> createState() =>
      _FirstPrayerSpeechPageState();
}

class _FirstPrayerSpeechPageState extends ConsumerState<FirstPrayerSpeechPage> {
  final _words = TextEditingController();
  var _available = false;
  var _initializing = true;
  var _listening = false;
  String? _notice;

  SpeechToText get _speech => ref.read(firstPrayerSpeechProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _notice =
              'Speak is available in the mobile app. You can write instead.';
        });
      }
      return;
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _listening = status == 'listening');
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _notice = 'Speak is unavailable. You can write instead.';
          });
        },
      );
      if (mounted) {
        setState(() {
          _available = available;
          _initializing = false;
          if (!available) {
            _notice = 'Speak is unavailable. You can write instead.';
          }
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _initializing = false;
          _notice = 'Speak is unavailable. You can write instead.';
        });
      }
    }
  }

  Future<void> _toggle() async {
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _notice = null);
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        onDevice: true,
        cancelOnError: true,
        partialResults: true,
      ),
    );
    if (mounted) setState(() => _listening = _speech.isListening);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _words.text = result.recognizedWords;
      _words.selection = TextSelection.collapsed(offset: _words.text.length);
    });
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Speak', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            const Text('Say a name, need, or a few words.'),
            const SizedBox(height: AppSpacing.lg),
            if (_initializing)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.icon(
                onPressed: _available ? _toggle : widget.onWriteInstead,
                icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                label: Text(
                  _available
                      ? _listening
                            ? 'Stop'
                            : 'Start speaking'
                      : 'Write instead',
                ),
              ),
            if (_notice case final notice?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(notice, textAlign: TextAlign.center),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('first-prayer-spoken-detail'),
              controller: _words,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Your words will appear here',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                final words = _words.text.trim();
                if (words.isNotEmpty) widget.onContinue(words);
              },
              child: const Text('Prepare prayer'),
            ),
            TextButton(onPressed: widget.onSkip, child: const Text('Not now')),
          ],
        ),
      ),
    ),
  );
}
