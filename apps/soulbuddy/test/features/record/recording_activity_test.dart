import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/recording_activity.dart';

void main() {
  test('an unsaved recording blocks navigation until its owner ends it', () {
    final activity = RecordingActivity();
    final owner = Object();
    final other = Object();
    expect(activity.active, isFalse);
    expect(activity.begin(owner), isTrue);
    expect(activity.begin(other), isFalse);
    activity.end(other);
    expect(activity.active, isTrue);
    activity.end(owner);
    expect(activity.active, isFalse);
  });
}
