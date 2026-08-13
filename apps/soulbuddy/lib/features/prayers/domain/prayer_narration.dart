import 'dart:typed_data';

class PrayerNarration {
  const PrayerNarration({
    required this.revisionId,
    required this.contentType,
    required this.bytes,
  });

  final String revisionId;
  final String contentType;
  final Uint8List bytes;
}
