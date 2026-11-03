import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/microphone_capture_lock.dart';

void main() {
  test('only the current owner can reserve or release the microphone', () {
    final lock = MicrophoneCaptureLock();
    final first = Object();
    final second = Object();
    lock.acquire(first);
    expect(() => lock.acquire(second), throwsStateError);
    lock.release(second);
    expect(() => lock.acquire(second), throwsStateError);
    lock.release(first);
    lock.acquire(second);
  });
}
