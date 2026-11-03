import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../record/audio/presentation/audio_playback_control.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/domain/encounter.dart';

/// New reflections play their original voice; older written reflections remain.
class MemoryReflectionContent extends ConsumerWidget {
  const MemoryReflectionContent({required this.reflection, super.key});

  final MemoryReflection reflection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioEncounterId = reflection.audioEncounterId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reflection.body.isNotEmpty) SelectableText(reflection.body),
        if (audioEncounterId != null)
          ref
              .watch(memoryAudioForEncounterProvider(audioEncounterId))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextButton(
                  onPressed: () => ref.invalidate(
                    memoryAudioForEncounterProvider(audioEncounterId),
                  ),
                  child: const Text('Retry recording'),
                ),
                data: (audio) => audio == null
                    ? const Text('Recording unavailable on this device')
                    : AudioPlaybackControl(
                        audio: audio,
                        label: 'Reflection',
                        sessionRoute: '/remember/${reflection.encounterId}',
                      ),
              ),
      ],
    );
  }
}
