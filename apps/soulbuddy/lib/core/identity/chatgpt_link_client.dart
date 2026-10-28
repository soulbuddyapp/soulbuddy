import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatgptLinkCode {
  const ChatgptLinkCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

class ChatgptLinkException implements Exception {
  const ChatgptLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owner-scoped SoulBuddy API client. OAuth credentials belong to ChatGPT,
/// never to this app, and link codes are deliberately not persisted here.
class ChatgptLinkClient {
  ChatgptLinkClient({
    required this.apiBaseUri,
    required this.accessToken,
    required this.httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;

  Future<bool> status() async {
    final response = await _request('GET', 'status');
    if (response.statusCode != 200) {
      throw const ChatgptLinkException(
        'Could not check the ChatGPT connection.',
      );
    }

    final data = _decode(response);
    if (data['linked'] is! bool) {
      throw const ChatgptLinkException('The connection response is invalid.');
    }
    return data['linked'] as bool;
  }

  Future<ChatgptLinkCode> createCode() async {
    final response = await _request('POST', 'link-codes');
    if (response.statusCode == 422) {
      throw const ChatgptLinkException(
        'Verify your SoulBuddy email above before linking ChatGPT.',
      );
    }
    if (response.statusCode != 201) {
      throw const ChatgptLinkException(
        'Could not create a link code. Try again.',
      );
    }

    final data = _decode(response);
    final code = data['code'];
    final expiry = data['expires_at'];
    final parsed = expiry is String ? DateTime.tryParse(expiry) : null;
    if (code is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(code) ||
        parsed == null) {
      throw const ChatgptLinkException('The link code response is invalid.');
    }

    return ChatgptLinkCode(code: code, expiresAt: parsed);
  }

  Future<bool> unlink() async {
    final response = await _request('POST', 'unlink');
    if (response.statusCode != 200) {
      throw const ChatgptLinkException(
        'Could not disconnect this account. Try again.',
      );
    }
    final data = _decode(response);
    if (data['unlinked'] is! bool) {
      throw const ChatgptLinkException('The disconnect response is invalid.');
    }
    return data['unlinked'] as bool;
  }

  Future<http.Response> _request(String method, String segment) async {
    final local =
        apiBaseUri.scheme == 'http' &&
        (apiBaseUri.host == 'localhost' ||
            apiBaseUri.host == '127.0.0.1' ||
            apiBaseUri.host == '::1');
    if (apiBaseUri.host.isEmpty ||
        apiBaseUri.userInfo.isNotEmpty ||
        (apiBaseUri.scheme != 'https' && !local)) {
      throw StateError('SoulBuddy account linking requires a secure API.');
    }

    final token = await accessToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('A signed-in SoulBuddy device session is required.');
    }

    final endpoint = apiBaseUri.replace(
      path:
          '${apiBaseUri.path.replaceFirst(RegExp(r'/$'), '')}/api/account/chatgpt/$segment',
      query: null,
      fragment: null,
    );
    final request = http.Request(method, endpoint)
      ..followRedirects = false
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer ${token.trim()}',
        if (method == 'POST') 'content-type': 'application/json',
      });
    if (method == 'POST') request.body = jsonEncode({'confirmed': true});

    final streamed = await httpClient.send(request).timeout(requestTimeout);
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(requestTimeout);
    // Reject redirects rather than carrying session credentials off-site.
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const ChatgptLinkException(
        'The account service returned an unexpected redirect.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ChatgptLinkException(
        'Your SoulBuddy session has expired. Reconnect to try again.',
      );
    }
    if (response.statusCode == 429) {
      throw const ChatgptLinkException('Too many attempts. Try again later.');
    }
    return response;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Avoid echoing server responses or personal data into UI errors.
    }
    throw const ChatgptLinkException(
      'The account service returned an invalid response.',
    );
  }
}
