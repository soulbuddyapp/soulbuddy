import 'dart:convert';

import 'package:http/http.dart' as http;

class AccountEmailChallenge {
  const AccountEmailChallenge({required this.id, required this.expiresAt});

  final String id;
  final DateTime expiresAt;
}

class AccountEmailLinkException implements Exception {
  const AccountEmailLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountEmailLinkClient {
  AccountEmailLinkClient({
    required this.apiBaseUri,
    required this.accessToken,
    required this.httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;

  Future<AccountEmailChallenge> request(String email) async {
    if (!apiBaseUri.hasScheme || apiBaseUri.host.isEmpty) {
      throw StateError('Email verification is unavailable.');
    }
    final token = await accessToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A verified device session is required.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const AccountEmailLinkException('Enter an email address.');
    }

    final endpoint = apiBaseUri.replace(
      path:
          '${apiBaseUri.path.replaceFirst(RegExp(r'/$'), '')}/api/account/email/challenges',
      query: null,
      fragment: null,
    );
    final response = await httpClient
        .post(
          endpoint,
          headers: {
            'accept': 'application/json',
            'authorization': 'Bearer ${token.trim()}',
            'content-type': 'application/json',
          },
          body: jsonEncode({'email': normalizedEmail}),
        )
        .timeout(requestTimeout);

    if (response.statusCode != 202) {
      throw const AccountEmailLinkException(
        'The verification email could not be sent. Try again shortly.',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const AccountEmailLinkException(
        'The verification response is invalid.',
      );
    }
    final challengeId = payload['challenge_id'];
    final expiresAt = payload['expires_at'];
    if (challengeId is! String || expiresAt is! String) {
      throw const AccountEmailLinkException(
        'The verification response is invalid.',
      );
    }
    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (parsedExpiry == null) {
      throw const AccountEmailLinkException(
        'The verification response is invalid.',
      );
    }

    return AccountEmailChallenge(id: challengeId, expiresAt: parsedExpiry);
  }
}
