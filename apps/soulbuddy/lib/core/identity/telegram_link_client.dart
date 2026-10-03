import 'dart:convert';

import 'package:http/http.dart' as http;

class TelegramLink {
  const TelegramLink({
    required this.code,
    required this.expiresAt,
    required this.startUrl,
  });

  final String code;
  final DateTime expiresAt;
  final Uri? startUrl;
}

class TelegramLinkException implements Exception {
  const TelegramLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TelegramLinkClient {
  TelegramLinkClient({
    required this.apiBaseUri,
    required this.accessToken,
    required this.httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;

  Future<TelegramLink> createLink() async {
    if (!apiBaseUri.hasScheme || apiBaseUri.host.isEmpty) {
      throw StateError('Telegram is unavailable.');
    }
    final token = await accessToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A verified device session is required.');
    }
    final endpoint = apiBaseUri.replace(
      path:
          '${apiBaseUri.path.replaceFirst(RegExp(r'/$'), '')}/api/companions/telegram/link-codes',
      query: null,
      fragment: null,
    );
    final response = await httpClient
        .post(
          endpoint,
          headers: {
            'accept': 'application/json',
            'authorization': 'Bearer ${token.trim()}',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode != 202) {
      throw const TelegramLinkException(
        'Telegram could not be connected. Try again shortly.',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> ||
        payload['code'] is! String ||
        payload['expires_at'] is! String) {
      throw const TelegramLinkException('The Telegram response is invalid.');
    }
    final expiresAt = DateTime.tryParse(payload['expires_at'] as String);
    final rawUrl = payload['start_url'];
    final startUrl = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (expiresAt == null || (rawUrl != null && startUrl == null)) {
      throw const TelegramLinkException('The Telegram response is invalid.');
    }

    return TelegramLink(
      code: payload['code'] as String,
      expiresAt: expiresAt,
      startUrl: startUrl,
    );
  }
}
