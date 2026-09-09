class OrientationCourse {
  const OrientationCourse({
    required this.id,
    required this.title,
    required this.tenet,
    required this.audioAsset,
    required this.transcriptAsset,
    required this.duration,
  });

  final String id;
  final String title;
  final String tenet;
  final String audioAsset;
  final String transcriptAsset;
  final Duration duration;

  factory OrientationCourse.fromJson(Map<String, dynamic> json) =>
      OrientationCourse(
        id: _string(json, 'id'),
        title: _string(json, 'title'),
        tenet: _string(json, 'tenet'),
        audioAsset: _string(json, 'audioAsset'),
        transcriptAsset: _string(json, 'transcriptAsset'),
        duration: Duration(milliseconds: _positiveInt(json, 'durationMs')),
      );
}

class TranscriptCue {
  const TranscriptCue({
    required this.startMs,
    required this.endMs,
    required this.charStart,
    required this.charEnd,
  });

  final int startMs;
  final int endMs;
  final int charStart;
  final int charEnd;

  factory TranscriptCue.fromJson(Map<String, dynamic> json) => TranscriptCue(
    startMs: _nonnegativeInt(json, 'startMs'),
    endMs: _positiveInt(json, 'endMs'),
    charStart: _nonnegativeInt(json, 'charStart'),
    charEnd: _positiveInt(json, 'charEnd'),
  );
}

class OrientationTranscript {
  const OrientationTranscript({
    required this.text,
    required this.words,
    required this.sentences,
    required this.duration,
  });

  final String text;
  final List<TranscriptCue> words;
  final List<TranscriptCue> sentences;
  final Duration duration;

  factory OrientationTranscript.fromJson(Map<String, dynamic> json) {
    final text = _string(json, 'text');
    final durationMs = _positiveInt(json, 'durationMs');
    List<TranscriptCue> cues(String key) {
      final raw = json[key];
      if (raw is! List) throw FormatException('Missing $key cues');
      var lastEnd = 0;
      var lastCharEnd = 0;
      final result = <TranscriptCue>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic>) {
          throw FormatException('Invalid $key cue');
        }
        final cue = TranscriptCue.fromJson(item);
        if (cue.startMs < lastEnd ||
            cue.endMs <= cue.startMs ||
            cue.endMs > durationMs ||
            cue.charStart < lastCharEnd ||
            cue.charEnd <= cue.charStart ||
            cue.charEnd > text.length) {
          throw FormatException('Invalid or unordered $key cue range');
        }
        result.add(cue);
        lastEnd = cue.endMs;
        lastCharEnd = cue.charEnd;
      }
      return List.unmodifiable(result);
    }

    return OrientationTranscript(
      text: text,
      words: cues('words'),
      sentences: cues('sentences'),
      duration: Duration(milliseconds: durationMs),
    );
  }

  /// Keep the sentence visible through pauses, until the next sentence begins.
  int? sentenceAt(Duration position) => _at(sentences, position, hold: true);

  /// A word is active only during its recorded speech boundary.
  int? wordAt(Duration position) => _at(words, position, hold: false);

  int? _at(List<TranscriptCue> cues, Duration position, {required bool hold}) {
    final milliseconds = position.inMilliseconds;
    if (position.isNegative || position >= duration || cues.isEmpty) {
      return null;
    }
    var low = 0;
    var high = cues.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (cues[middle].startMs <= milliseconds) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final index = low - 1;
    if (index < 0 || (!hold && milliseconds >= cues[index].endMs)) return null;
    return index;
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

int _nonnegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException('Invalid $key');
  return value;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = _nonnegativeInt(json, key);
  if (value == 0) throw FormatException('Invalid $key');
  return value;
}
