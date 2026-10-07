import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/plugin_speech_recognizer.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';

/// Stands in for the real store so no filesystem or platform channel is
/// reached. Only its existence matters: nothing here records or deletes.
class _UnusedAssetStore implements AudioAssetStore {
  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) async {}

  @override
  Future<void> delete(String storageKey) async {}

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async => CommittedAudio(storageKey: assetId, byteSize: 0);

  @override
  Future<void> discardTemporary(String locator) async {}

  @override
  Future<AudioPlaybackSource?> open(String storageKey) async => null;

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) async => TemporaryAudio(key: takeId, locator: '$takeId.$extension');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The `record` plugin's own channel. `AudioRecorder()` also sends `create`
  // from its constructor and the gateway subscribes to amplitudes, so the
  // handler answers every method rather than only the one under test.
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  final recordCalls = <MethodCall>[];
  var permissionGranted = true;

  setUp(() {
    recordCalls.clear();
    permissionGranted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async {
          recordCalls.add(call);
          return switch (call.method) {
            'hasPermission' => permissionGranted,
            'create' || 'dispose' => null,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  ProviderContainer containerWith({
    AudioAssetStore? assetStore,
    List<Object> extraOverrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        audioAssetStoreProvider.overrideWith(
          (ref) async => assetStore ?? _UnusedAssetStore(),
        ),
        // `Override` is not exported, so the caller's overrides arrive as the
        // same runtime type the container expects.
        ...extraOverrides.cast(),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('every field shares one controller', () {
    final container = containerWith();

    final first = container.read(speechCaptureControllerProvider);
    final second = container.read(speechCaptureControllerProvider);

    expect(
      identical(first, second),
      isTrue,
      reason:
          'a controller each would mean an initialisation each, and the '
          'last one registered would take the seam callbacks',
    );
  });

  test('the controller is disposed with its container', () {
    final container = containerWith();
    final controller = container.read(speechCaptureControllerProvider);
    void listener() {}
    expect(() => controller.addListener(listener), returnsNormally);

    container.dispose();

    expect(
      () => controller.addListener(listener),
      throwsFlutterError,
      reason:
          'a field that outlives its container would notify a dead notifier',
    );
  });

  test('a second container starts a second session state', () {
    final first = containerWith();
    final second = containerWith();

    expect(
      identical(
        first.read(speechCaptureControllerProvider),
        second.read(speechCaptureControllerProvider),
      ),
      isFalse,
    );
  });

  test('the app recogniser is the plugin adapter, so it can ask', () {
    final container = containerWith();

    expect(
      container.read(speechRecognizerProvider),
      isA<PluginSpeechRecognizer>(),
      reason: 'only the plugin adapter knows it must ask for the microphone',
    );
  });

  test('the controller drives the shared recogniser', () async {
    // The controller resolves availability through the recogniser, so this is
    // the observable proof the two are wired to each other rather than the
    // controller quietly building its own.
    var initialised = 0;
    containerWith(
      extraOverrides: [
        speechRecognizerProvider.overrideWithValue(
          _CountingRecognizer(onInitialize: () => initialised++),
        ),
      ],
    ).read(speechCaptureControllerProvider).ensureAvailable();

    await Future<void>.delayed(Duration.zero);

    expect(initialised, 1);
  });

  test('initialising the shared recogniser asks for the microphone', () async {
    // Reached through the `record` plugin the app already depends on. Without
    // this, `speech_to_text` fails for a reason nobody can act on: it never
    // prompts, and the app otherwise only holds RECORD_AUDIO as a side effect
    // of someone recording a memory.
    final container = containerWith();

    final granted = await container.read(speechRecognizerProvider).initialize();

    expect(granted, isFalse, reason: 'the speech channel is not mocked here');
    expect(recordCalls.map((call) => call.method), contains('hasPermission'));
  });

  test(
    'a refused microphone stops the recogniser being asked to start',
    () async {
      permissionGranted = false;
      final container = containerWith();

      expect(
        await container.read(speechRecognizerProvider).initialize(),
        isFalse,
      );
      expect(recordCalls.map((call) => call.method), contains('hasPermission'));
    },
  );

  test('asking for the microphone releases the recorder it borrowed', () async {
    // Dictation only needs the answer. The `record` gateway it borrows creates
    // a native recorder, so holding one for the app's lifetime would keep a
    // microphone resource open that nothing here records through.
    await containerWith().read(speechRecognizerProvider).initialize();

    expect(
      recordCalls.map((call) => call.method),
      containsAllInOrder(['hasPermission', 'dispose']),
    );
  });
}

class _CountingRecognizer implements SpeechRecognizer {
  _CountingRecognizer({required this.onInitialize});

  final void Function() onInitialize;

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
    VoidCallback? onError,
  }) async {
    onInitialize();
    return true;
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {}

  @override
  Future<void> stop() async {}
}
