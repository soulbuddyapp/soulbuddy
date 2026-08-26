import 'package:flutter/foundation.dart';

import '../../record/audio/domain/memory_audio.dart';

const maximumPrayerRefrainDuration = Duration(seconds: 25);

enum VoiceTabletSourceType {
  personalPrayer('personal_prayer'),
  libraryPrayer('library_prayer');

  const VoiceTabletSourceType(this.wireValue);
  final String wireValue;

  factory VoiceTabletSourceType.fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw const FormatException('Unknown Voice Tablet source'),
  );
}

enum VoiceTabletAudioKind {
  fullPrayer('full_prayer'),
  refrain('refrain');

  const VoiceTabletAudioKind(this.wireValue);
  final String wireValue;

  factory VoiceTabletAudioKind.fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () =>
        throw const FormatException('Unknown Voice Tablet audio kind'),
  );
}

@immutable
class VoiceTabletSource {
  VoiceTabletSource._({
    required this.type,
    required String prayerId,
    String? revisionId,
  }) : prayerId = _requiredText(prayerId, 'prayerId', 128),
       revisionId = revisionId == null
           ? null
           : _requiredText(revisionId, 'revisionId', 128) {
    if (type == VoiceTabletSourceType.personalPrayer &&
        this.revisionId == null) {
      throw ArgumentError('A personal prayer requires an exact revision.');
    }
    if (type == VoiceTabletSourceType.libraryPrayer &&
        this.revisionId != null) {
      throw ArgumentError('A library prayer does not accept a revision.');
    }
  }

  factory VoiceTabletSource.personal({
    required String prayerId,
    required String revisionId,
  }) => VoiceTabletSource._(
    type: VoiceTabletSourceType.personalPrayer,
    prayerId: prayerId,
    revisionId: revisionId,
  );

  factory VoiceTabletSource.library({required String prayerId}) =>
      VoiceTabletSource._(
        type: VoiceTabletSourceType.libraryPrayer,
        prayerId: prayerId,
      );

  final VoiceTabletSourceType type;
  final String prayerId;
  final String? revisionId;

  @override
  bool operator ==(Object other) =>
      other is VoiceTabletSource &&
      other.type == type &&
      other.prayerId == prayerId &&
      other.revisionId == revisionId;

  @override
  int get hashCode => Object.hash(type, prayerId, revisionId);
}

@immutable
class VoiceTabletAudio {
  VoiceTabletAudio({
    required String id,
    required this.kind,
    required String storageKey,
    required String mimeType,
    required this.duration,
    required this.byteSize,
    required List<double> waveform,
    required this.createdAt,
  }) : id = _requiredText(id, 'id', 128),
       storageKey = _requiredText(storageKey, 'storageKey', 1024),
       mimeType = _audioMimeType(mimeType),
       waveform = List.unmodifiable(_waveform(waveform)) {
    final maximum = kind == VoiceTabletAudioKind.refrain
        ? maximumPrayerRefrainDuration
        : maximumMemoryAudioDuration;
    if (duration < const Duration(milliseconds: 1) || duration > maximum) {
      throw ArgumentError.value(duration, 'duration');
    }
    if (byteSize < 1 || byteSize > maximumMemoryAudioBytes) {
      throw ArgumentError.value(byteSize, 'byteSize');
    }
  }

  final String id;
  final VoiceTabletAudioKind kind;
  final String storageKey;
  final String mimeType;
  final Duration duration;
  final int byteSize;
  final List<double> waveform;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is VoiceTabletAudio &&
      other.id == id &&
      other.kind == kind &&
      other.storageKey == storageKey &&
      other.mimeType == mimeType &&
      other.duration == duration &&
      other.byteSize == byteSize &&
      listEquals(other.waveform, waveform) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    storageKey,
    mimeType,
    duration,
    byteSize,
    Object.hashAll(waveform),
    createdAt,
  );
}

@immutable
class VoiceTablet {
  VoiceTablet({
    required String id,
    required String ownerId,
    required this.source,
    required String title,
    this.fullAudio,
    required this.createdAt,
    required this.updatedAt,
    this.refrainAudio,
    this.archivedAt,
  }) : id = _requiredText(id, 'id', 128),
       ownerId = _requiredText(ownerId, 'ownerId', 128),
       title = _requiredText(title, 'title', 120) {
    if (fullAudio != null &&
        fullAudio!.kind != VoiceTabletAudioKind.fullPrayer) {
      throw ArgumentError.value(fullAudio!.kind, 'fullAudio');
    }
    if (refrainAudio != null &&
        refrainAudio!.kind != VoiceTabletAudioKind.refrain) {
      throw ArgumentError.value(refrainAudio!.kind, 'refrainAudio');
    }
  }

  final String id;
  final String ownerId;
  final VoiceTabletSource source;
  final String title;
  final VoiceTabletAudio? fullAudio;
  final VoiceTabletAudio? refrainAudio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  @override
  bool operator ==(Object other) =>
      other is VoiceTablet &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.source == source &&
      other.title == title &&
      other.fullAudio == fullAudio &&
      other.refrainAudio == refrainAudio &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt;

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    source,
    title,
    fullAudio,
    refrainAudio,
    createdAt,
    updatedAt,
    archivedAt,
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
