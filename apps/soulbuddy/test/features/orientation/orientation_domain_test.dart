import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';

void main() {
  final json = <String, dynamic>{
    'text': 'Hello. Welcome.',
    'durationMs': 3000,
    'words': [
      {'startMs': 100, 'endMs': 700, 'charStart': 0, 'charEnd': 6},
      {'startMs': 1000, 'endMs': 2000, 'charStart': 7, 'charEnd': 15},
    ],
    'sentences': [
      {'startMs': 100, 'endMs': 700, 'charStart': 0, 'charEnd': 6},
      {'startMs': 1000, 'endMs': 2000, 'charStart': 7, 'charEnd': 15},
    ],
  };

  test(
    'cue lookup uses media time, exclusive ends and gaps in either direction',
    () {
      final transcript = OrientationTranscript.fromJson(json);
      expect(transcript.wordAt(const Duration(milliseconds: 100)), 0);
      expect(transcript.wordAt(const Duration(milliseconds: 700)), isNull);
      expect(transcript.sentenceAt(const Duration(milliseconds: 800)), 0);
      expect(transcript.wordAt(const Duration(milliseconds: 1200)), 1);
      expect(transcript.sentenceAt(const Duration(milliseconds: 200)), 0);
      expect(transcript.sentenceAt(Duration.zero), isNull);
      expect(transcript.sentenceAt(const Duration(seconds: 3)), isNull);
    },
  );

  test('invalid cue ranges and out of order cues are rejected', () {
    expect(
      () => OrientationTranscript.fromJson({
        ...json,
        'words': [
          {'startMs': 0, 'endMs': 3100, 'charStart': 0, 'charEnd': 6},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => OrientationTranscript.fromJson({
        ...json,
        'words': [
          {'startMs': 1000, 'endMs': 2000, 'charStart': 7, 'charEnd': 99},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => OrientationTranscript.fromJson({
        ...json,
        'words': (json['words'] as List).reversed.toList(),
      }),
      throwsFormatException,
    );
  });

  test('catalog course parses its duration and assets', () {
    final course = OrientationCourse.fromJson({
      'id': 'welcome',
      'title': 'Welcome',
      'tenet': 'Begin',
      'audioAsset': 'assets/audio/welcome.mp3',
      'transcriptAsset': 'assets/orientation/welcome.json',
      'durationMs': 3000,
    });
    expect(course.duration, const Duration(seconds: 3));
    expect(course.id, 'welcome');
  });
}
