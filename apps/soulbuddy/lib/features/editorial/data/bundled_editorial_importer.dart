import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:powersync/powersync.dart';

import '../domain/editorial_item.dart';

class BundledEditorialImporter {
  BundledEditorialImporter({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const assetPath = 'assets/content/editorial_manifest.json';
  static const supportedManifestVersion = 1;

  final AssetBundle _assetBundle;

  Future<void> ensureLoaded(PowerSyncDatabase database) async {
    final source = await _assetBundle.loadString(assetPath);
    final items = _decodeAndValidate(source);

    await database.writeTransaction((transaction) async {
      final ids = items.map((item) => item.id).toList(growable: false);
      final placeholders = List.filled(ids.length, '?').join(', ');
      await transaction.execute(
        '''
        UPDATE editorial_items
        SET archived_at = ?
        WHERE archived_at IS NULL AND id NOT IN ($placeholders)
        ''',
        [DateTime.now().toUtc().toIso8601String(), ...ids],
      );

      for (final item in items) {
        final existing = await transaction.getOptional(
          'SELECT id FROM editorial_items WHERE id = ?',
          [item.id],
        );
        final values = [
          item.kind.wireValue,
          item.contentVersion,
          item.provenance,
          item.sourceRef,
          item.reviewState.wireValue,
          _dateKey(item.reviewedOn),
          item.publishedAt?.toIso8601String(),
          jsonEncode(item.tags),
        ];
        if (existing == null) {
          await transaction.execute(
            '''
            INSERT INTO editorial_items(
              id, content_kind, content_version, provenance, source_ref,
              review_state, reviewed_on, published_at, archived_at, tags_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
            ''',
            [item.id, ...values],
          );
          continue;
        }

        await transaction.execute(
          '''
          UPDATE editorial_items
          SET content_kind = ?, content_version = ?, provenance = ?, source_ref = ?,
              review_state = ?, reviewed_on = ?, published_at = ?, archived_at = NULL,
              tags_json = ?
          WHERE id = ?
          ''',
          [...values, item.id],
        );
      }
    });
  }

  List<EditorialItem> _decodeAndValidate(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid editorial manifest JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Editorial manifest must be an object.');
    }
    _validateAllowedKeys(
      decoded,
      allowedKeys: _allowedRootKeys,
      scope: 'root key',
    );
    if (decoded['version'] != supportedManifestVersion) {
      throw FormatException(
        'Unsupported editorial manifest version: ${decoded['version']}.',
      );
    }
    final rawItems = decoded['items'];
    if (rawItems is! List<dynamic> || rawItems.isEmpty) {
      throw const FormatException('Editorial manifest needs at least one item.');
    }
    final items = rawItems.map(_itemFromJson).toList(growable: false);
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw const FormatException('Editorial item IDs must be unique.');
    }
    return items;
  }

  EditorialItem _itemFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Each editorial item must be an object.');
    }
    _validateAllowedKeys(
      value,
      allowedKeys: _allowedItemKeys,
      scope: 'item field',
    );

    final id = _requiredString(value, 'id');
    if (!_uuidPattern.hasMatch(id)) {
      throw FormatException('Editorial item "$id" does not have a valid UUID.');
    }
    final kind = EditorialContentKind.fromWire(
      _requiredString(value, 'kind'),
    );
    final contentVersion = value['content_version'];
    if (contentVersion is! int || contentVersion <= 0) {
      throw const FormatException(
        'Editorial item field "content_version" must be a positive integer.',
      );
    }
    final reviewState = EditorialReviewState.fromWire(
      _requiredString(value, 'review_state'),
    );
    final reviewedOn = _requiredDate(value, 'reviewed_on');
    final publishedAt = _optionalDateTime(value, 'published_at');
    if (reviewState == EditorialReviewState.approved && publishedAt == null) {
      throw FormatException(
        'Approved editorial item "$id" requires published_at.',
      );
    }
    final tags = _tags(value['tags']);

    return EditorialItem(
      id: id,
      kind: kind,
      contentVersion: contentVersion,
      provenance: _requiredString(value, 'provenance'),
      sourceRef: _requiredString(value, 'source_ref'),
      reviewState: reviewState,
      reviewedOn: reviewedOn,
      publishedAt: publishedAt,
      tags: tags,
    );
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

const _allowedRootKeys = {'version', 'items'};
const _allowedItemKeys = {
  'id',
  'kind',
  'content_version',
  'provenance',
  'source_ref',
  'review_state',
  'reviewed_on',
  'published_at',
  'tags',
};

void _validateAllowedKeys(
  Map<String, dynamic> value, {
  required Set<String> allowedKeys,
  required String scope,
}) {
  final unexpected = value.keys.where((key) => !allowedKeys.contains(key)).toList()
    ..sort();
  if (unexpected.isNotEmpty) {
    throw FormatException(
      'Unexpected editorial manifest $scope: ${unexpected.first}.',
    );
  }
}

String _requiredString(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw FormatException(
      'Editorial item field "$key" must be a non-empty string.',
    );
  }
  return field.trim();
}

DateTime _requiredDate(Map<String, dynamic> value, String key) {
  final field = _requiredString(value, key);
  if (!_datePattern.hasMatch(field)) {
    throw FormatException('Editorial item field "$key" must be YYYY-MM-DD.');
  }
  final parsed = DateTime.tryParse('${field}T00:00:00.000Z');
  if (parsed == null || _dateKey(parsed) != field) {
    throw FormatException('Editorial item field "$key" is not a valid date.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDateTime(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field == null) return null;
  if (field is! String || field.trim().isEmpty) {
    throw FormatException(
      'Editorial item field "$key" must be omitted or an ISO-8601 timestamp.',
    );
  }
  final parsed = DateTime.tryParse(field);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException(
      'Editorial item field "$key" must be an ISO-8601 UTC timestamp.',
    );
  }
  return parsed;
}

List<String> _tags(Object? value) {
  if (value is! List<dynamic> || value.isEmpty) {
    throw const FormatException(
      'Editorial item field "tags" must be a non-empty string list.',
    );
  }
  final tags = <String>[];
  for (final rawTag in value) {
    if (rawTag is! String || rawTag.trim().isEmpty) {
      throw const FormatException(
        'Editorial item field "tags" must contain non-empty strings.',
      );
    }
    final tag = rawTag.trim();
    if (tags.contains(tag)) {
      throw FormatException('Editorial item tags must be unique: $tag.');
    }
    tags.add(tag);
  }
  return List.unmodifiable(tags);
}

String _dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
