import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The spoken audio for one release item, when the server has validated it.
class PrayerReleaseNarration {
  const PrayerReleaseNarration({
    required this.contentSha256,
    required this.narrationUri,
  });

  /// The hash of the exact item content this audio speaks.
  final String contentSha256;

  /// The opaque asset reference the server issued for that audio.
  final String narrationUri;
}

/// A release item's narration request could not be satisfied.
class PrayerReleaseNarrationException implements Exception {
  const PrayerReleaseNarrationException(this.code);

  /// A machine code, never server prose.
  final String code;

  @override
  String toString() => code;
}

/// Narration for a release item, served only when the recorded transcript is
/// the exact content the person can see.
abstract interface class PrayerReleaseNarrationRepository {
  /// The approved paces, with 0.85x as the starting pace.
  static const double defaultSpeed = 0.85;
  static const List<double> availableSpeeds = [0.7, 0.85, 1.0, 1.15];

  /// Returns null when the item has no validated asset, meaning the person
  /// reads the same visible text in silence.
  Future<PrayerReleaseNarration?> load(String releaseItemId);

  /// Fetches the audio bytes for a validated asset.
  Future<Uint8List> bytes(PrayerReleaseNarration narration);
}

/// Reads narration from the account's server.
class LaravelPrayerReleaseNarrationRepository
    implements PrayerReleaseNarrationRepository {
  LaravelPrayerReleaseNarrationRepository({
    required this.apiBaseUri,
    required this.accessToken,
    required this.httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;

  @override
  Future<PrayerReleaseNarration?> load(String releaseItemId) async {
    final token = await _token();
    final response = await httpClient
        .get(
          _endpoint('/api/prayer-release-items/$releaseItemId/narration'),
          headers: {
            'accept': 'application/json',
            'authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);

    if (response.statusCode == 404) {
      // The collection was not added, so there is nothing to narrate.
      throw const PrayerReleaseNarrationException('release_not_added');
    }
    if (response.statusCode == 503) {
      throw const PrayerReleaseNarrationException('narration_unavailable');
    }
    if (response.statusCode != 200) {
      throw const PrayerReleaseNarrationException('narration_unavailable');
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) {
      throw const PrayerReleaseNarrationException('narration_invalid_response');
    }
    if (payload['status'] == 'text_only') {
      // The server serves the exact visible text instead of any audio.
      return null;
    }
    if (payload['status'] != 'ready' ||
        payload['narration_uri'] is! String ||
        payload['content_sha256'] is! String) {
      throw const PrayerReleaseNarrationException('narration_invalid_response');
    }

    return PrayerReleaseNarration(
      contentSha256: payload['content_sha256'] as String,
      narrationUri: payload['narration_uri'] as String,
    );
  }

  @override
  Future<Uint8List> bytes(PrayerReleaseNarration narration) async {
    final token = await _token();
    final response = await httpClient
        .get(
          _endpoint('/api/prayer-release-narration/${narration.narrationUri}'),
          headers: {'accept': 'audio/mpeg', 'authorization': 'Bearer $token'},
        )
        .timeout(requestTimeout);

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw const PrayerReleaseNarrationException('narration_unavailable');
    }

    return response.bodyBytes;
  }

  Future<String> _token() async {
    if (!apiBaseUri.hasScheme || apiBaseUri.host.isEmpty) {
      throw StateError('Weekly prayers are unavailable.');
    }
    final token = await accessToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A verified device session is required.');
    }

    return token.trim();
  }

  Uri _endpoint(String path) => apiBaseUri.replace(
    path: '${apiBaseUri.path.replaceFirst(RegExp(r'/$'), '')}$path',
    query: null,
    fragment: null,
  );
}
