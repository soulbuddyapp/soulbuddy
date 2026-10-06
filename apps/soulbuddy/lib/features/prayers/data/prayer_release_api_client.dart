import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/prayer_release.dart';

/// A release response could not be read or refreshed.
class PrayerReleaseApiException implements Exception {
  const PrayerReleaseApiException(this.code);

  /// A machine code, never server prose.
  final String code;

  @override
  String toString() => code;
}

/// The discovery list plus this account's preference.
class PrayerReleaseSnapshot {
  const PrayerReleaseSnapshot({
    required this.releases,
    required this.preference,
  });

  final List<PrayerRelease> releases;
  final PrayerReleasePreference preference;
}

/// The complete release content returned by an add.
class PrayerReleaseAdded {
  const PrayerReleaseAdded({
    required this.release,
    required this.preparationText,
    required this.items,
    required this.preference,
  });

  final PrayerRelease release;
  final String preparationText;
  final List<PrayerReleaseItemContent> items;
  final PrayerReleasePreference preference;
}

/// A one-shot authenticated client for release discovery, preferences, and the
/// deliberate add.
class PrayerReleaseApiClient {
  PrayerReleaseApiClient({
    required this.apiBaseUri,
    required this.accessToken,
    required this.httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;

  Future<PrayerReleaseSnapshot> fetch() async {
    final response = await _send('GET', '/api/prayer-releases');
    if (response.statusCode != 200) {
      throw const PrayerReleaseApiException('release_unavailable');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['releases'] is! List) {
      throw const PrayerReleaseApiException('release_invalid_response');
    }

    return PrayerReleaseSnapshot(
      releases: (payload['releases'] as List)
          .map((entry) => _releaseFromRow(entry, addedPayload: false))
          .toList(growable: false),
      preference: _preferenceFromRow(payload['preference']),
    );
  }

  Future<PrayerReleaseAdded> add(String slug) async {
    final response = await _send('POST', '/api/prayer-releases/$slug/add');
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const PrayerReleaseApiException('release_add_failed');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> ||
        payload['items'] is! List ||
        payload['preparation_text'] is! String) {
      throw const PrayerReleaseApiException('release_invalid_response');
    }

    return PrayerReleaseAdded(
      release: _releaseFromRow(payload, addedPayload: true),
      preparationText: payload['preparation_text'] as String,
      items: (payload['items'] as List)
          .map((entry) => _contentFromRow(payload, entry as Map<String, dynamic>))
          .toList(growable: false),
      preference: _preferenceFromRow(payload['preference']),
    );
  }

  Future<PrayerReleasePreference> savePreference(
    PrayerReleasePreference preference,
  ) async {
    final response = await _send(
      'PUT',
      '/api/prayer-release-preference',
      body: jsonEncode({
        'weekly_enabled': preference.weeklyEnabled,
        'notification_enabled': preference.notificationEnabled,
        'time_zone': preference.timeZone,
      }),
    );
    if (response.statusCode != 200) {
      throw const PrayerReleaseApiException('preference_save_failed');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const PrayerReleaseApiException('release_invalid_response');
    }

    return _preferenceFromRow(payload['preference']);
  }

  PrayerReleaseItemContent _contentFromRow(
    Map<String, dynamic> release,
    Map<String, dynamic> row,
  ) {
    final practice = row['practice'];
    final steps = practice is Map<String, dynamic> && practice['steps'] is List
        ? (practice['steps'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return PrayerReleaseItemContent(
      releaseId: release['id'] as String,
      releaseSlug: release['slug'] as String,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      kind: PrayerReleaseItemKindValue.fromWire(row['kind'] as String),
      libraryPrayerId: row['library_prayer_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      contentSha256: row['content_sha256'] as String,
      itemId: row['id'] as String?,
      grounding: row['grounding'] as String?,
      languageStyle: row['language_style'] as String?,
      purpose: row['purpose'] as String?,
      action: row['action'] as String?,
      practice: practice is Map<String, dynamic> && steps.isNotEmpty
          ? PrayerReleasePractice(
              mode: practice['mode'] as String,
              steps: [
                for (final step in steps)
                  PrayerReleasePracticeStep(
                    phrase: step['phrase'] as String,
                    targetCount: (step['target_count'] as num).toInt(),
                    sourceLine: step['source_line'] as String,
                  ),
              ],
            )
          : null,
    );
  }

  PrayerRelease _releaseFromRow(
    Map<String, dynamic> row, {
    required bool addedPayload,
  }) {
    if (row['id'] is! String ||
        row['slug'] is! String ||
        row['title'] is! String ||
        row['discovery_label'] is! String ||
        row['discovery_detail'] is! String ||
        row['items'] is! List) {
      throw const PrayerReleaseApiException('release_invalid_response');
    }

    return PrayerRelease(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: row['title'] as String,
      discoveryLabel: row['discovery_label'] as String,
      discoveryDetail: row['discovery_detail'] as String,
      publishedAt: DateTime.tryParse(row['published_at'] as String? ?? ''),
      addedAt: DateTime.tryParse(row['added_at'] as String? ?? ''),
      items: (row['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) {
            if (item['id'] is! String ||
                item['sort_order'] is! num ||
                item['kind'] is! String ||
                item['library_prayer_id'] is! String) {
              throw const PrayerReleaseApiException('release_invalid_response');
            }

            return PrayerReleaseItem(
              id: item['id'] as String,
              sortOrder: (item['sort_order'] as num).toInt(),
              kind: PrayerReleaseItemKindValue.fromWire(item['kind'] as String),
              libraryPrayerId: item['library_prayer_id'] as String,
              title: item['title'] as String?,
              hasAttentionPractice: item['has_attention_practice'] == true,
              narrationAvailable: item['narration_available'] == true,
            );
          })
          .toList(growable: false),
    );
  }

  PrayerReleasePreference _preferenceFromRow(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const PrayerReleasePreference();
    }

    return PrayerReleasePreference(
      weeklyEnabled: value['weekly_enabled'] == true,
      notificationEnabled: value['notification_enabled'] != false,
      timeZone: value['time_zone'] as String?,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    String? body,
  }) async {
    if (!apiBaseUri.hasScheme || apiBaseUri.host.isEmpty) {
      throw StateError('Weekly prayers are unavailable.');
    }
    final token = await accessToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A verified device session is required.');
    }

    final endpoint = apiBaseUri.replace(
      path: '${apiBaseUri.path.replaceFirst(RegExp(r'/$'), '')}$path',
      query: null,
      fragment: null,
    );
    final headers = {
      'accept': 'application/json',
      'authorization': 'Bearer ${token.trim()}',
      if (body != null) 'content-type': 'application/json',
    };

    final response = switch (method) {
      'GET' => httpClient.get(endpoint, headers: headers),
      'POST' => httpClient.post(endpoint, headers: headers),
      'PUT' => httpClient.put(
        endpoint,
        headers: headers,
        body: body,
      ),
      _ => throw ArgumentError.value(method, 'method'),
    };

    return response.timeout(requestTimeout);
  }
}
