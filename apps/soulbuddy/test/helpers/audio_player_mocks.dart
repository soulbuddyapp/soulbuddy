import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Allows capture UI tests to exercise playback teardown without native audio.
Future<void> installAudioPlayerMocks() async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers.global/events',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'];
        messenger.setMockMethodCallHandler(
          MethodChannel('xyz.luan/audioplayers/events/$id'),
          (_) async => null,
        );
      }
      return null;
    },
  );
  // Run in setUp, before the widget test enters FakeAsync. AudioPlayer caches
  // this completer globally; a completed future owned by an earlier fake zone
  // must not strand a later test's awaited stop/dispose operations.
  await AudioPlayer.global.ensureInitialized();
}
