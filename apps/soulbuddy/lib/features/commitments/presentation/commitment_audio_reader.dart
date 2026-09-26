import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/presentation/screen_awake.dart';
import '../application/commitment_audio.dart';

/// Reviewed words remain available even if the optional audio catalog fails.
Future<CommitmentAudioAsset> loadCommitmentReading(
  String id, {
  String fallback = '',
  Future<CommitmentAudioAsset> Function(String) catalogLoader =
      CommitmentAudioAsset.load,
  Future<String> Function(String)? textLoader,
}) async {
  try {
    return await catalogLoader(id);
  } catch (_) {
    String transcript;
    try {
      transcript = await (textLoader ?? rootBundle.loadString)(
        'assets/audio/commitments/$id.txt',
      );
      if (transcript.trim().isEmpty) throw const FormatException();
    } catch (_) {
      transcript = reviewedCommitmentTranscriptFallbacks[id] ?? fallback;
    }
    return CommitmentAudioAsset(
      id: id,
      path: '',
      transcript: transcript.trim(),
      captions: const [],
      duration: Duration.zero,
    );
  }
}

class CommitmentAudioReader extends StatefulWidget {
  const CommitmentAudioReader({
    required this.assetId,
    this.fallback = '',
    super.key,
  });
  final String assetId;
  final String fallback;
  @override
  State<CommitmentAudioReader> createState() => _CommitmentAudioReaderState();
}

class _CommitmentAudioReaderState extends State<CommitmentAudioReader> {
  final audio = CommitmentAudio();
  late Future<CommitmentAudioAsset> _asset;
  @override
  void initState() {
    super.initState();
    _asset = loadCommitmentReading(widget.assetId, fallback: widget.fallback);
  }

  @override
  void didUpdateWidget(covariant CommitmentAudioReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      unawaited(audio.stop());
      _asset = loadCommitmentReading(widget.assetId, fallback: widget.fallback);
    }
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PracticeAudioScope(
    onVisibilityChanged: (visible) {
      if (!visible) unawaited(audio.pause());
    },
    child: FutureBuilder<CommitmentAudioAsset>(
      future: _asset,
      builder: (context, snapshot) {
        return ListenableBuilder(
          listenable: audio,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed:
                        snapshot.hasData && snapshot.data!.path.isNotEmpty
                        ? () async {
                            if (audio.playing) {
                              await audio.pause();
                            } else if (audio.asset?.id == widget.assetId &&
                                !audio.complete &&
                                !audio.unavailable) {
                              await audio.resume();
                            } else {
                              await audio.play(widget.assetId);
                            }
                          }
                        : null,
                    icon: Icon(audio.playing ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      audio.playing
                          ? 'Pause'
                          : audio.complete
                          ? 'Replay'
                          : 'Listen',
                    ),
                  ),
                  DropdownButton<double>(
                    value: audio.speed,
                    underline: const SizedBox.shrink(),
                    items: [.65, .75, .85, 1.0, 1.15]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v}x',
                              semanticsLabel: 'Narration speed $v',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) unawaited(audio.setSpeed(v));
                    },
                  ),
                ],
              ),
              if (audio.unavailable ||
                  snapshot.hasError ||
                  (snapshot.hasData && snapshot.data!.path.isEmpty))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Audio unavailable. Continue reading.'),
                ),
              const SizedBox(height: 16),
              if (snapshot.hasData)
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * .42).clamp(
                    220.0,
                    400.0,
                  ),
                  child: SingleChildScrollView(
                    child: CommitmentTranscript(
                      asset: snapshot.data!,
                      position: audio.position,
                      playing: audio.playing,
                    ),
                  ),
                )
              else
                Text(
                  widget.fallback,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
            ],
          ),
        );
      },
    ),
  );
}

class CommitmentTranscript extends StatefulWidget {
  const CommitmentTranscript({
    required this.asset,
    required this.position,
    required this.playing,
    this.followInitially = true,
    super.key,
  });
  final CommitmentAudioAsset asset;
  final Duration position;
  final bool playing;
  final bool followInitially;
  @override
  State<CommitmentTranscript> createState() => _CommitmentTranscriptState();
}

class _CommitmentTranscriptState extends State<CommitmentTranscript> {
  final Map<int, GlobalKey> _keys = {};
  var _last = -1;
  late bool _follow = widget.followInitially;
  @override
  Widget build(BuildContext context) {
    final captions = widget.asset.captions;
    final index = captions.indexWhere(
      (c) =>
          widget.position.inMilliseconds >= (c['startMs'] as num) &&
          widget.position.inMilliseconds < (c['endMs'] as num),
    );
    if (index != _last && index >= 0 && _follow && widget.playing) {
      _last = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _keys[index]?.currentContext;
        if (mounted && target != null) {
          Scrollable.of(target).position.ensureVisible(
            target.findRenderObject()!,
            alignment: .45,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          );
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (captions.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _follow = !_follow;
                _last = -1;
              }),
              icon: Icon(_follow ? Icons.sync : Icons.sync_disabled, size: 16),
              label: Text(_follow ? 'Follow narration' : 'Manual scrolling'),
            ),
          ),
        if (captions.isEmpty)
          SelectableText(widget.asset.transcript)
        else
          ...captions.asMap().entries.map(
            (entry) => Container(
              key: _keys.putIfAbsent(entry.key, GlobalKey.new),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: index == entry.key
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
              ),
              child: Text(
                entry.value['text'] as String,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.65,
                  color: index == entry.key
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CommitmentReadinessScreen extends StatelessWidget {
  const CommitmentReadinessScreen({super.key});
  @override
  Widget build(BuildContext context) => ScreenAwake(
    child: Scaffold(
      appBar: AppBar(title: const Text('A word about readiness')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: CommitmentAudioReader(
            assetId: 'readiness_v1',
            fallback:
                'What am I asking God to give me, form in me, and help me carry?',
          ),
        ),
      ),
    ),
  );
}

// Emergency text-only fallbacks mirror the approved catalog, verified by tests.
const reviewedCommitmentTranscriptFallbacks = <String, String>{
  "readiness_v1":
      "Imagine a three-year-old looking up and saying, “I’m ready to get married. I would like my own home.” You may be stunned for a moment, and most of us laugh. A real desire can be real before a person is ready to carry its weight. Sometimes we ask God to reveal our purpose before we are formed to carry it. Moses wanted to free his enslaved brothers, but the desert became a place of formation. He waited, and God formed him for the mission in God’s timing. We are created by God. In Christ, our whole life—spirit, mind, body, desires, habits, and work—can be brought back to God. Scripture, prayer, a willing attitude, and healthy activity help form us; they are not a spiritual performance. Prayer is not dependent on a perfect posture or a perfectly quiet room. When you can, turn toward God deliberately. What are you asking God to give you, form in you, and help you carry?",
  "invitation_v1":
      "What you name before God can shape the way you live. A commitment is not pretending to be finished. It is presenting your life honestly and asking the Father, through Jesus Christ, to reshape your desires, your calling, and your daily choices. You do not carry this alone. Bring it into His presence now.",
  "guide_surrender_v1":
      "Be still, and know that I am God. Let distracting thoughts pass rather than chasing them. You do not have to solve every feeling or hurry toward a spiritual experience. Receive whatever stillness is available. Focus on the divine Father, approached through Jesus. Present your needs, your calling, and your daily practices to God. Tell Him what you hope for, what you fear, and what you are trying to do with the life He has given you. Surrender your desires and choices. You are not alone, and you do not need to carry this commitment by yourself. Let honesty take the place of performance. Receive what is already yours in Christ. Stay in this place for a moment and listen. Now listen.",
  "guide_direction_v1":
      "Be still, and know that I am God. Let distracting thoughts pass rather than chasing them. You do not have to solve every feeling or hurry toward a spiritual experience. Receive whatever stillness is available. Focus on the divine Father, approached through Jesus. Present your needs, your calling, and your daily practices to God. Tell Him what you hope for, what you fear, and what you are trying to do with the life He has given you. Bring what you believe God has called you to do or become into the light. Ask for clarity around your next faithful step. Receive wisdom, and do not confuse urgency with direction. A calling may take time to become clear. You can ask, listen, learn, and choose the next faithful act without pretending to see the whole road. Now listen.",
  "guide_peace_v1":
      "Be still, and know that I am God. Let distracting thoughts pass rather than chasing them. You do not have to solve every feeling or hurry toward a spiritual experience. Receive whatever stillness is available. Focus on the divine Father, approached through Jesus. Present your needs, your calling, and your daily practices to God. Tell Him what you hope for, what you fear, and what you are trying to do with the life He has given you. Receive God’s presence without trying to manufacture it. Quiet distraction, receive comfort, and let this time become a small faithful practice of attention. You are not required to feel a particular way. Let grace reshape your attention, and receive the peace that is already present in Christ. Now listen.",
  "listening_v1":
      "You have practiced turning toward God. Now practice listening. You do not have to force a revelation or manufacture a feeling. Notice what Scripture stirs in you, what distracts you, and what faithful response is possible. The divine Father, approached through Jesus, can speak through His Word, through wisdom, through circumstances, and through a clear next act. Let the silence become a place where you do not rush to fill every space. Receive what is present, and remain open to correction. You do not need to understand the whole road to take the next faithful step. Now listen.",
  "spoken_invitation_v1":
      "This is a time to be with God, if you can. Open SoulBuddy when you are ready.",
};
