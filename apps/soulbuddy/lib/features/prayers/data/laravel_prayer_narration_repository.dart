import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/prayer_narration.dart';
import 'prayer_narration_repository.dart';

export 'prayer_narration_repository.dart' show PrayerNarrationException;

class LaravelPrayerNarrationRepository implements PrayerNarrationRepository {
  LaravelPrayerNarrationRepository({
    required this.apiBaseUri,
    required this.accessToken,
    required this.client,
    this.disclosureVersion = 'deepgram-aura2-1',
  });

  static const maximumBytes = 2000000;

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client client;
  final String disclosureVersion;

  @override
  Future<PrayerNarration> prepare({
    required String personalPrayerId,
    required String prayerRevisionId,
    required bool consent,
  }) async {
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const PrayerNarrationException('authentication_required');
    }
    final response = await client.post(
      _resolve('/api/prayer-narrations'),
      headers: {
        'authorization': 'Bearer $token',
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'personal_prayer_id': personalPrayerId,
        'prayer_revision_id': prayerRevisionId,
        'disclosure_version': disclosureVersion,
        'consent': consent,
      }),
    );
    if (response.statusCode != 200) {
      throw PrayerNarrationException(_code(response));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['status'] != 'ready' ||
        decoded['revision_id'] != prayerRevisionId ||
        decoded['content_type'] != 'audio/mpeg' ||
        decoded['playback_url'] is! String) {
      throw const PrayerNarrationException('invalid_response');
    }
    final playback = await client.get(
      _resolve(decoded['playback_url'] as String),
      headers: {'authorization': 'Bearer $token', 'accept': 'audio/mpeg'},
    );
    final type = playback.headers['content-type']?.split(';').first.trim();
    if (playback.statusCode != 200 ||
        type != 'audio/mpeg' ||
        playback.bodyBytes.isEmpty ||
        playback.bodyBytes.length > maximumBytes) {
      throw const PrayerNarrationException('invalid_audio');
    }
    return PrayerNarration(
      revisionId: prayerRevisionId,
      contentType: type!,
      bytes: Uint8List.fromList(playback.bodyBytes),
    );
  }

  Uri _resolve(String pathOrUrl) {
    final parsed = Uri.tryParse(pathOrUrl);
    if (parsed != null && parsed.hasScheme) return parsed;
    final normalized = apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '');
    final path = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    return Uri.parse('$normalized$path');
  }

  String _code(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['code'] is String) {
        return decoded['code'] as String;
      }
    } catch (_) {
      // Content-free fallback below.
    }
    return 'narration_unavailable';
  }
}
