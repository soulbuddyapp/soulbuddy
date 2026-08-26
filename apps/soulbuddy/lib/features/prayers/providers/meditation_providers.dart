import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/meditation_sound_bed_player.dart';

final meditationSoundBedPlayerProvider =
    Provider.autoDispose<MeditationSoundBedPlayer>((ref) {
      final player = AudioplayersMeditationSoundBedPlayer();
      ref.onDispose(() => unawaited(player.dispose()));
      return player;
    });
