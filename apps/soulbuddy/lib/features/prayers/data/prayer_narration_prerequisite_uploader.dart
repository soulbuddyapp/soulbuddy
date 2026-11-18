import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import 'prayer_narration_repository.dart';

class PrayerNarrationPrerequisiteUploader {
  PrayerNarrationPrerequisiteUploader({
    required this.database,
    required this.apiBaseUri,
    required this.installationId,
    required this.accessToken,
    required this.client,
    this.timeout = const Duration(seconds: 30),
  });

  final PowerSyncDatabase database;
  final Uri apiBaseUri;
  final String installationId;
  final Future<String?> Function() accessToken;
  final http.Client client;
  final Duration timeout;

  Future<void> upload({
    required String personalPrayerId,
    required String revisionId,
  }) async {
    final prayer = await database.getOptional(
      '''
      SELECT * FROM personal_prayers
      WHERE id = ? AND current_revision_id = ? AND archived_at IS NULL
      LIMIT 1
      ''',
      [personalPrayerId, revisionId],
    );
    final revision = await database.getOptional(
      '''
      SELECT * FROM personal_prayer_revisions
      WHERE id = ? AND prayer_id = ?
      LIMIT 1
      ''',
      [revisionId, personalPrayerId],
    );
    if (prayer == null || revision == null) {
      throw const PrayerNarrationException('narration_unavailable');
    }
    if (revision['content_format'] == 'audio') {
      throw const PrayerNarrationException('recorded_prayer_has_audio');
    }
    final operations = [
      _operation(
        table: 'personal_prayers',
        id: personalPrayerId,
        data: {
          'owner_id': prayer['owner_id'],
          'title': prayer['title'],
          'style': prayer['style'],
          'reach': prayer['reach'],
          'grounding': prayer['grounding'],
          'purpose': prayer['purpose'],
          'current_revision_id': revisionId,
          'created_at': prayer['created_at'],
          'updated_at': prayer['updated_at'],
          'archived_at': prayer['archived_at'],
        },
      ),
      _operation(
        table: 'personal_prayer_revisions',
        id: revisionId,
        data: {
          'owner_id': revision['owner_id'],
          'prayer_id': personalPrayerId,
          'body': revision['body'],
          'action': revision['action'],
          'device_id': revision['device_id'],
          'created_at': revision['created_at'],
        },
      ),
    ];
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const PrayerNarrationException('authentication_required');
    }
    late final http.Response response;
    try {
      response = await client
          .post(
            _apiUri('/api/sync/mutations'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode({'operations': operations}),
          )
          .timeout(timeout);
    } on Exception {
      throw const PrayerNarrationException('narration_unavailable');
    }
    if (response.statusCode != 200) {
      throw const PrayerNarrationException('narration_unavailable');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['accepted'] != 2 ||
          body['rejected'] != 0) {
        throw const PrayerNarrationException('narration_unavailable');
      }
    } on FormatException {
      throw const PrayerNarrationException('narration_unavailable');
    }
  }

  Map<String, Object?> _operation({
    required String table,
    required String id,
    required Map<String, Object?> data,
  }) {
    final canonical = jsonEncode(_canonicalJson(data));
    return {
      'operation_id': const Uuid().v5(
        Namespace.url.value,
        'soulbuddy:narration-prerequisite:$installationId:$table:$id:$canonical',
      ),
      'table': table,
      'type': 'put',
      'id': id,
      'data': data,
    };
  }

  Uri _apiUri(String path) {
    final normalized = apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$normalized$path');
  }
}

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalJson(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalJson).toList(growable: false);
  }
  return value;
}
