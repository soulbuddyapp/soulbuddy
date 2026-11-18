/// Tracks an open recording, including its unsaved review and retry states.
class RecordingActivity {
  Object? _owner;
  bool get active => _owner != null;

  bool begin(Object owner) {
    if (_owner != null && !identical(_owner, owner)) return false;
    _owner = owner;
    return true;
  }

  void end(Object owner) {
    if (identical(_owner, owner)) _owner = null;
  }
}
