import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/practice_audio_scope.dart';
import '../application/commitment_audio.dart';
import '../application/commitment_session_clock.dart';
import 'commitment_audio_reader.dart';

class CommitmentInvitationView extends StatefulWidget {
  const CommitmentInvitationView({
    required this.onContinue,
    required this.onReadiness,
    this.voice,
    this.music,
    this.bell,
    this.elapsed,
    super.key,
  });
  final VoidCallback onContinue;
  final VoidCallback onReadiness;
  final CommitmentAudio? voice, music, bell;
  final Duration Function()? elapsed;
  @override
  State<CommitmentInvitationView> createState() =>
      _CommitmentInvitationViewState();
}

class _CommitmentInvitationViewState extends State<CommitmentInvitationView> {
  late final CommitmentAudio _voice = widget.voice ?? CommitmentAudio();
  late final CommitmentAudio _music = (widget.music ?? CommitmentAudio())
    ..speed = 1;
  late final CommitmentAudio _bell = (widget.bell ?? CommitmentAudio())
    ..speed = 1;
  late CommitmentSessionClock _clock = _newClock();
  late final Future<CommitmentAudioAsset> _transcript = loadCommitmentReading(
    'invitation_v1',
  );
  Timer? _ticker;
  bool _started = false,
      _musicStarted = false,
      _bellStarted = false,
      _dead = false;
  bool _muted = false;
  double _lastMusicGain = 0;

  CommitmentSessionClock _newClock() => CommitmentSessionClock(
    planned: const Duration(seconds: 45),
    elapsed: widget.elapsed,
  );
  double _musicGain(double t) => t < 6
      ? .08
      : t < 15
      ? .14
      : t < 24
      ? .18
      : t < 34
      ? .24
      : t < 41
      ? .30
      : .12;

  Future<void> _play() async {
    if (_clock.completed) {
      _clock = _newClock();
      _started = false;
      _musicStarted = false;
      _bellStarted = false;
    }
    _clock.start();
    if (!_started) {
      _started = true;
      unawaited(_voice.play('invitation_v1', volume: _muted ? 0 : 1));
    } else {
      if (!_voice.complete) unawaited(_voice.resume());
      if (_musicStarted && !_music.complete) unawaited(_music.resume());
      if (_bellStarted && !_bell.complete) unawaited(_bell.resume());
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_dead) return;
      final t = _clock.actual.inMilliseconds / 1000;
      final gain = _musicGain(t);
      if (t >= 8 && !_musicStarted) {
        _musicStarted = true;
        _lastMusicGain = gain;
        unawaited(
          _music.play('aphelion_excerpt_v1', volume: _muted ? 0 : gain),
        );
      } else if (_musicStarted && gain != _lastMusicGain) {
        _lastMusicGain = gain;
        unawaited(_music.setVolume(_muted ? 0 : gain));
      }
      if (t >= 41 && !_bellStarted) {
        _bellStarted = true;
        unawaited(
          _bell.playPath(
            'assets/audio/sacred_hours/sacred_still_bell.wav',
            volume: _muted ? 0 : .45,
          ),
        );
      }
      if (_clock.completed) {
        _ticker?.cancel();
        unawaited(_voice.stop());
        unawaited(_music.stop());
        unawaited(_bell.stop());
      }
      setState(() {});
    });
    setState(() {});
  }

  void _pause() {
    _clock.pause();
    _ticker?.cancel();
    unawaited(_voice.pause());
    unawaited(_music.pause());
    unawaited(_bell.pause());
    if (mounted && !_dead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_dead) setState(() {});
      });
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    unawaited(_voice.setVolume(_muted ? 0 : 1));
    unawaited(
      _music.setVolume(
        _muted ? 0 : _musicGain(_clock.actual.inMilliseconds / 1000),
      ),
    );
    unawaited(_bell.setVolume(_muted ? 0 : .45));
  }

  @override
  void dispose() {
    _dead = true;
    _ticker?.cancel();
    if (widget.voice == null) {
      _voice.dispose();
    } else {
      unawaited(_voice.stop());
    }
    if (widget.music == null) {
      _music.dispose();
    } else {
      unawaited(_music.stop());
    }
    if (widget.bell == null) {
      _bell.dispose();
    } else {
      unawaited(_bell.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _clock.actual.inMilliseconds / 1000;
    final text = t < 6
        ? 'Be still. You are not alone.'
        : t < 15
        ? 'Receive what God has already given.'
        : t < 24
        ? 'Present your life honestly before Him.'
        : t < 34
        ? 'Offer your calling and your daily choices.'
        : t < 41
        ? 'You do not carry this commitment alone.'
        : 'A commitment begins in God’s presence.';
    final reduce = MediaQuery.disableAnimationsOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return PracticeAudioScope(
      onVisibilityChanged: (visible) {
        if (!visible) _pause();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: largeText ? 180 : 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(
                      scale: reduce ? 1 : 1 + (t / 45) * .04,
                      child: Image.asset(
                        'assets/images/sanctuary/ascent.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: t >= (reduce ? 41 : 34) ? 1 : 0,
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 1200),
                      child: Image.asset(
                        'assets/images/sanctuary/sacred_hour_portal.webp',
                        fit: BoxFit.cover,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF14261F).withValues(alpha: .6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _clock.running ? _pause : _play,
            icon: Icon(_clock.running ? Icons.pause : Icons.play_arrow),
            label: Text(
              _clock.running
                  ? 'Pause'
                  : _clock.completed
                  ? 'Replay'
                  : _started
                  ? 'Continue invitation'
                  : 'Play the invitation',
            ),
          ),
          TextButton.icon(
            onPressed: _toggleMute,
            icon: Icon(
              _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            ),
            label: Text(_muted ? 'Unmute' : 'Mute'),
          ),
          if (_started) LinearProgressIndicator(value: t / 45),
          TextButton(
            onPressed: () {
              _pause();
              widget.onContinue();
            },
            child: Text(_clock.completed ? 'I’m ready' : 'Skip to quiet place'),
          ),
          TextButton(
            onPressed: () {
              _pause();
              widget.onReadiness();
            },
            child: const Text('Why wait? A word about readiness'),
          ),
          const SizedBox(height: 16),
          FutureBuilder<CommitmentAudioAsset>(
            future: _transcript,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Text(
                  reviewedCommitmentTranscriptFallbacks['invitation_v1']!,
                  style: const TextStyle(height: 1.7),
                );
              }
              return ListenableBuilder(
                listenable: _voice,
                builder: (context, _) => CommitmentTranscript(
                  asset: snapshot.data!,
                  position: _voice.position,
                  playing: _voice.playing,
                  followInitially: false,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
