import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:powersync/powersync.dart';

import '../domain/library_prayer.dart';

class BundledPrayerImporter {
  BundledPrayerImporter({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const assetPath = 'assets/content/prayer_library.json';
  static const supportedContentVersion = 1;

  final AssetBundle _assetBundle;

  Future<void> ensureLoaded(PowerSyncDatabase database) async {
    final source = await _assetBundle.loadString(assetPath);
    final prayers = _decodeAndValidate(source);

    await database.writeTransaction((transaction) async {
      for (final prayer in prayers) {
        final existing = await transaction.getOptional(
          'SELECT id FROM bundled_prayers WHERE id = ?',
          [prayer.id],
        );
        if (existing == null) {
          await transaction.execute(
            '''
            INSERT INTO bundled_prayers(
              id, title, body, grounding, purpose, action, helpful_count,
              content_version, archived_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
            ''',
            [
              prayer.id,
              prayer.title,
              prayer.body,
              prayer.grounding,
              prayer.purpose,
              prayer.action,
              prayer.helpfulCount,
              supportedContentVersion,
            ],
          );
          continue;
        }

        await transaction.execute(
          '''
          UPDATE bundled_prayers
          SET title = ?, body = ?, grounding = ?, purpose = ?, action = ?,
              helpful_count = ?, content_version = ?, archived_at = NULL
          WHERE id = ?
          ''',
          [
            prayer.title,
            prayer.body,
            prayer.grounding,
            prayer.purpose,
            prayer.action,
            prayer.helpfulCount,
            supportedContentVersion,
            prayer.id,
          ],
        );
      }
    });
  }

  List<_BundledPrayer> _decodeAndValidate(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid bundled prayer JSON: ${error.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bundled prayer content must be an object.');
    }
    if (decoded['version'] != supportedContentVersion) {
      throw FormatException(
        'Unsupported bundled prayer content version: ${decoded['version']}.',
      );
    }

    final prayerValues = decoded['prayers'];
    if (prayerValues is! List<dynamic>) {
      throw const FormatException(
        'Bundled prayer content needs a prayer list.',
      );
    }

    final prayers = prayerValues
        .map(_BundledPrayer.fromJson)
        .toList(growable: false);
    if (prayers.length != PrayerPurpose.values.length) {
      throw FormatException(
        'Bundled prayer content must contain exactly '
        '${PrayerPurpose.values.length} prayers.',
      );
    }

    final ids = prayers.map((prayer) => prayer.id).toSet();
    if (ids.length != prayers.length) {
      throw const FormatException('Bundled prayer IDs must be unique.');
    }

    final purposes = prayers.map((prayer) => prayer.purpose).toSet();
    final approvedPurposes = PrayerPurpose.values
        .map((purpose) => purpose.wireValue)
        .toSet();
    if (purposes.length != prayers.length ||
        !purposes.containsAll(approvedPurposes)) {
      throw const FormatException(
        'Bundled prayers must cover every approved purpose exactly once.',
      );
    }

    return prayers;
  }
}

class _BundledPrayer {
  const _BundledPrayer({
    required this.id,
    required this.title,
    required this.body,
    required this.grounding,
    required this.purpose,
    required this.action,
    required this.helpfulCount,
  });

  factory _BundledPrayer.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Each bundled prayer must be an object.');
    }

    final id = _requiredString(value, 'id');
    final title = _requiredString(value, 'title');
    final body = _requiredString(value, 'body');
    final grounding = _requiredString(value, 'grounding');
    final purpose = _requiredString(value, 'purpose');
    final action = _optionalString(value, 'action');
    final helpfulCount = value['helpful_count'];

    if (!_uuidPattern.hasMatch(id)) {
      throw FormatException('Bundled prayer "$id" does not have a valid UUID.');
    }
    PrayerGrounding.fromWire(grounding);
    PrayerPurpose.fromWire(purpose);
    if (_wordCount(body) > 110) {
      throw FormatException('Bundled prayer "$id" exceeds 110 words.');
    }
    if (helpfulCount is! int) {
      throw const FormatException(
        'Bundled prayer field "helpful_count" must be an integer.',
      );
    }
    if (helpfulCount != 0) {
      throw FormatException(
        'Bundled prayer field "helpful_count" must be 0 for "$id".',
      );
    }

    return _BundledPrayer(
      id: id,
      title: title,
      body: body,
      grounding: grounding,
      purpose: purpose,
      action: action,
      helpfulCount: helpfulCount,
    );
  }

  final String id;
  final String title;
  final String body;
  final String grounding;
  final String purpose;
  final String? action;
  final int helpfulCount;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _requiredString(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw FormatException(
      'Bundled prayer field "$key" must be a non-empty string.',
    );
  }
  return field.trim();
}

String? _optionalString(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field == null) {
    return null;
  }
  if (field is! String || field.trim().isEmpty) {
    throw FormatException(
      'Bundled prayer field "$key" must be omitted or a non-empty string.',
    );
  }
  return field.trim();
}

int _wordCount(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
}
