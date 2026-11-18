import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../application/bundled_prayer_audio.dart';

abstract interface class BundledPrayerVoice {
  Stream<void> get completions;
  Future<void> play(String asset);
  Future<void> stop();
  Future<void> dispose();
}

class _AudioPlayerVoice implements BundledPrayerVoice {
  final _player = AudioPlayer();
  @override
  Stream<void> get completions => _player.onPlayerComplete;
  @override
  Future<void> play(String asset) => _player.play(
    AssetSource(asset),
    ctx: AudioContextConfig(
      respectSilence: true,
      focus: AudioContextConfigFocus.gain,
    ).build(),
  );
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

class BundledPrayerAudioSection extends StatefulWidget {
  const BundledPrayerAudioSection({
    super.key,
    required this.prayerId,
    required this.body,
    this.autoplay = false,
  });
  final bool autoplay;
  final String prayerId;
  final String body;
  @override
  State<BundledPrayerAudioSection> createState() =>
      _BundledPrayerAudioSectionState();
}

class _BundledPrayerAudioSectionState extends State<BundledPrayerAudioSection> {
  late Future<String?> _asset;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BundledPrayerAudioSection old) {
    super.didUpdateWidget(old);
    if (old.prayerId != widget.prayerId || old.body != widget.body) _load();
  }

  void _load() {
    _asset = BundledPrayerAudioCatalog.load().then(
      (value) => value.assetFor(widget.prayerId, widget.body),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _asset,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return OutlinedButton(
          onPressed: () => setState(_load),
          child: const Text('Try prayer audio again'),
        );
      }
      final asset = snapshot.data;
      if (asset == null) return const SizedBox.shrink();
      return BundledPrayerAudioButton(
        key: ValueKey(asset),
        asset: asset,
        autoplay: widget.autoplay,
      );
    },
  );
}

class BundledPrayerAudioButton extends StatefulWidget {
  const BundledPrayerAudioButton({
    super.key,
    required this.asset,
    this.voice,
    this.autoplay = false,
  });
  final String asset;
  final BundledPrayerVoice? voice;
  final bool autoplay;
  @override
  State<BundledPrayerAudioButton> createState() =>
      _BundledPrayerAudioButtonState();
}

class _BundledPrayerAudioButtonState extends State<BundledPrayerAudioButton> {
  late final BundledPrayerVoice voice = widget.voice ?? _AudioPlayerVoice();
  StreamSubscription<void>? subscription;
  bool playing = false, busy = false, failed = false;
  @override
  void initState() {
    super.initState();
    subscription = voice.completions.listen((_) {
      if (mounted) setState(() => playing = false);
    });
    if (widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !playing && !busy) unawaited(toggle());
      });
    }
  }

  @override
  void didUpdateWidget(covariant BundledPrayerAudioButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autoplay && widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !playing && !busy) unawaited(toggle());
      });
    }
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    unawaited(voice.dispose());
    super.dispose();
  }

  Future<void> toggle() async {
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      if (playing) {
        await voice.stop();
      } else {
        await voice.play(widget.asset);
      }
      if (mounted) setState(() => playing = !playing);
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          playing = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: busy ? null : toggle,
        icon: Icon(playing ? Icons.stop : Icons.play_arrow),
        label: Text(playing ? 'Stop prayer' : 'Play prayer'),
      ),
      if (failed) const Text('Prayer audio could not play. Try again.'),
    ],
  );
}
