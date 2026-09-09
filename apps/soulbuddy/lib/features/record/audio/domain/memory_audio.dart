import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'memory_soundscape.dart';

const maximumMemoryAudioDuration = Duration(minutes: 15);
const maximumMemoryAudioBytes = 64 * 1024 * 1024;
const maximumMemoryAudioWaveformSamples = 96;

class RecordedAudioDraft {
  RecordedAudioDraft({
    required String temporaryKey,
    required String mimeType,
    required Duration duration,
    required List<double> waveform,
    this.soundscape = MemorySoundscape.quiet,
    this.soundscapeVolume = 0.15,
  }) : temporaryKey = _requiredText(temporaryKey, 'temporaryKey', 1024),
       mimeType = _audioMimeType(mimeType),
       duration = _duration(duration),
       waveform = List.unmodifiable(_waveform(waveform));

  final String temporaryKey;
  final String mimeType;
  final Duration duration;
  final List<double> waveform;
  final MemorySoundscape soundscape;
  final double soundscapeVolume;
}

/// Compatibility name for encounter audio while prayer recording adopts the
/// reusable [RecordedAudioDraft] terminology.
typedef MemoryAudioDraft = RecordedAudioDraft;

@immutable
class MemoryAudio {
  MemoryAudio({
    required String id,
    required String encounterId,
    required String revisionId,
    required String storageKey,
    required String mimeType,
    required Duration duration,
    required int byteSize,
    required List<double> waveform,
    required this.createdAt,
  }) : id = _requiredText(id, 'id', 128),
       encounterId = _requiredText(encounterId, 'encounterId', 128),
       revisionId = _requiredText(revisionId, 'revisionId', 128),
       storageKey = _requiredText(storageKey, 'storageKey', 1024),
       mimeType = _audioMimeType(mimeType),
       duration = _duration(duration),
       byteSize = _byteSize(byteSize),
       waveform = List.unmodifiable(_waveform(waveform));

  final String id;
  final String encounterId;
  final String revisionId;
  final String storageKey;
  final String mimeType;
  final Duration duration;
  final int byteSize;
  final List<double> waveform;
  final DateTime createdAt;

  factory MemoryAudio.fromRow(Map<String, dynamic> row) {
    final decoded = jsonDecode(row['waveform_json'] as String);
    if (decoded is! List) {
      throw const FormatException('Invalid memory audio waveform');
    }
    return MemoryAudio(
      id: row['id'] as String,
      encounterId: row['encounter_id'] as String,
      revisionId: row['encounter_revision_id'] as String,
      storageKey: row['storage_key'] as String,
      mimeType: row['mime_type'] as String,
      duration: Duration(milliseconds: row['duration_ms'] as int),
      byteSize: row['byte_size'] as int,
      waveform: decoded
          .map((value) {
            if (value is! num) {
              throw const FormatException('Invalid memory audio waveform');
            }
            return value.toDouble();
          })
          .toList(growable: false),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MemoryAudio &&
      other.id == id &&
      other.encounterId == encounterId &&
      other.revisionId == revisionId &&
      other.storageKey == storageKey &&
      other.mimeType == mimeType &&
      other.duration == duration &&
      other.byteSize == byteSize &&
      listEquals(other.waveform, waveform) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    encounterId,
    revisionId,
    storageKey,
    mimeType,
    duration,
    byteSize,
    Object.hashAll(waveform),
    createdAt,
  );
}

String _requiredText(String value, String name, int maximumLength) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.length > maximumLength ||
      normalized.contains('\u0000')) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}

String _audioMimeType(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.length > 127 ||
      !RegExp(r'^audio/[a-z0-9][a-z0-9.+-]*$').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'mimeType');
  }
  return normalized;
}

Duration _duration(Duration value) {
  if (value < const Duration(milliseconds: 1) ||
      value > maximumMemoryAudioDuration) {
    throw ArgumentError.value(value, 'duration');
  }
  return value;
}

int _byteSize(int value) {
  if (value < 1 || value > maximumMemoryAudioBytes) {
    throw ArgumentError.value(value, 'byteSize');
  }
  return value;
}

List<double> _waveform(List<double> values) {
  if (values.isEmpty || values.length > maximumMemoryAudioWaveformSamples) {
    throw ArgumentError.value(values, 'waveform');
  }
  return values
      .map((value) {
        if (!value.isFinite) throw ArgumentError.value(values, 'waveform');
        return value.clamp(0.0, 1.0).toDouble();
      })
      .toList(growable: false);
}
