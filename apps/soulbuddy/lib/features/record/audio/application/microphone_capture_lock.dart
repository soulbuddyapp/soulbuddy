class MicrophoneCaptureLock {
  Object? _owner;

  void acquire(Object owner) {
    if (_owner != null && !identical(_owner, owner)) {
      throw StateError('Another recording is active');
    }
    _owner = owner;
  }

  void release(Object owner) {
    if (identical(_owner, owner)) _owner = null;
  }
}
