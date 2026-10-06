import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';

void main() {
  test('every field shares one controller', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

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
    final container = ProviderContainer();
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
    final first = ProviderContainer();
    final second = ProviderContainer();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    expect(
      identical(
        first.read(speechCaptureControllerProvider),
        second.read(speechCaptureControllerProvider),
      ),
      isFalse,
    );
  });
}
