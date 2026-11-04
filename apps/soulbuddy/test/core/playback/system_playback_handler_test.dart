import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';
import 'package:soulbuddy/core/playback/system_playback_handler.dart';

void main() {
  test(
    'system controls respect capture and do not complete a prayer',
    () async {
      final controller = SpiritualSessionController();
      final handler = SystemPlaybackHandler(controller);
      var playing = false;
      var completed = false;
      Duration? sought;
      await controller.begin(
        SpiritualSession(
          id: 'private-id',
          kind: SpiritualSessionKind.prayer,
          title: 'private prayer',
          route: '/',
          canPause: true,
          supportsSystemPlayback: true,
          onStart: () async => playing = true,
          onPause: () async => playing = false,
          onResume: () async => playing = true,
          onComplete: () async => completed = true,
          onClose: () async => playing = false,
          onSeek: (position) async => sought = position,
        ),
      );
      expect(handler.mediaItem.value?.title, 'Voice recording');
      expect(handler.mediaItem.value?.id, isNot('private-id'));
      expect(handler.playbackState.value.playing, isTrue);
      await handler.seek(const Duration(seconds: 3));
      expect(sought, const Duration(seconds: 3));
      await handler.pause();
      expect(playing, isFalse);
      await handler.play();
      expect(playing, isTrue);
      final owner = Object();
      await controller.acquireCapture(owner);
      await handler.play();
      expect(playing, isFalse);
      await handler.stop();
      expect(completed, isFalse);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      controller.releaseCapture(owner);
      handler.dispose();
      controller.dispose();
    },
  );
}
