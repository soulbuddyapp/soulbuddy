import 'dart:convert';

import 'package:http/http.dart' as http;

class FormationActivityClient {
  FormationActivityClient({
    required this.apiBaseUri,
    required this.accessToken,
    required this.httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;

  Future<bool> recordOpened(String videoId) =>
      _record(videoId, activityType: 'opened');

  Future<bool> recordCompleted(String videoId) =>
      _record(videoId, activityType: 'completed');

  Future<bool> _record(String videoId, {required String activityType}) async {
    if (!apiBaseUri.hasScheme || apiBaseUri.host.isEmpty) return false;
    final token = await accessToken();
    if (token == null || token.trim().isEmpty) return false;
    final basePath = apiBaseUri.path.replaceFirst(RegExp(r'/$'), '');
    final endpoint = apiBaseUri.replace(
      path: '$basePath/api/formation/activity',
      query: null,
      fragment: null,
    );
    try {
      final response = await httpClient
          .post(
            endpoint,
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
              'authorization': 'Bearer ${token.trim()}',
            },
            body: jsonEncode({
              'formation_video_id': videoId,
              'activity_type': activityType,
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 201) return false;
      final payload = jsonDecode(response.body);
      return payload is Map<String, dynamic> && payload['recorded'] == true;
    } on Exception {
      return false;
    }
  }
}
