import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/identity/local_identity_providers.dart';
import '../domain/circle.dart';
import 'circle_directory_repository.dart';

class CircleDirectoryUnavailable implements Exception {
  const CircleDirectoryUnavailable([this.statusCode]);

  final int? statusCode;

  @override
  String toString() => 'Circles are temporarily unavailable.';
}

class CircleDirectoryForbidden implements Exception {
  const CircleDirectoryForbidden();
}

class LaravelCircleDirectoryRepository implements CircleDirectoryRepository {
  LaravelCircleDirectoryRepository({
    required this.apiBaseUri,
    required this.tokenReader,
    required this.client,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri apiBaseUri;
  final AppSessionTokenReader tokenReader;
  final http.Client client;
  final Duration requestTimeout;

  @override
  Future<CirclePage> discover(CircleDiscoveryQuery query) async {
    final parameters = <String, String>{
      if (query.category case final category?)
        'category': category.wireValue,
      if (query.search?.trim() case final search? when search.isNotEmpty)
        'q': search,
      if (query.cursor case final cursor?) 'cursor': cursor,
      'limit': query.limit.toString(),
    };
    final response = await _get('/api/circles', query: parameters);
    final payload = _object(response.body);
    final data = payload['data'];
    if (data is! List<dynamic>) throw const CircleDirectoryUnavailable();
    final items = data.map(_circle).toList(growable: false);
    final nextCursor = payload['next_cursor'];
    if (nextCursor != null && nextCursor is! String) {
      throw const CircleDirectoryUnavailable();
    }
    return CirclePage(
      items: List.unmodifiable(items),
      nextCursor: nextCursor as String?,
    );
  }

  @override
  Future<List<Circle>> listOwned() async {
    final response = await _get('/api/circles/mine');
    final payload = _object(response.body);
    final data = payload['data'];
    if (data is! List<dynamic>) throw const CircleDirectoryUnavailable();
    return List.unmodifiable(data.map(_circle));
  }

  @override
  Future<Circle?> get(String publicId) async {
    final response = await _request(
      'GET',
      '/api/circles/${Uri.encodeComponent(publicId)}',
      allowNotFound: true,
    );
    if (response.statusCode == 404) return null;
    return _circle(_object(response.body));
  }

  @override
  Future<Circle> create(CircleDraft draft) async {
    final response = await _request(
      'POST',
      '/api/circles',
      body: draft.toJson(),
    );
    return _circle(_object(response.body));
  }

  @override
  Future<Circle> update(String publicId, CircleUpdate update) async {
    final response = await _request(
      'PATCH',
      '/api/circles/${Uri.encodeComponent(publicId)}',
      body: update.toJson(),
    );
    return _circle(_object(response.body));
  }

  @override
  Future<void> report(String publicId, String reason) async {
    await _request(
      'POST',
      '/api/circles/${Uri.encodeComponent(publicId)}/reports',
      body: {'reason': reason},
    );
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
  }) {
    return _request('GET', path, query: query);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool allowNotFound = false,
  }) async {
    final token = await tokenReader();
    if (token == null || token.isEmpty) {
      throw const CircleDirectoryUnavailable(401);
    }
    final uri = _uri(path, query);
    final headers = {
      'authorization': 'Bearer $token',
      'accept': 'application/json',
      if (body != null) 'content-type': 'application/json',
    };
    final future = switch (method) {
      'GET' => client.get(uri, headers: headers),
      'POST' => client.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'PATCH' => client.patch(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      _ => throw ArgumentError.value(method, 'method'),
    };
    final response = await future.timeout(requestTimeout);
    if (allowNotFound && response.statusCode == 404) return response;
    if (response.statusCode == 403) throw const CircleDirectoryForbidden();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CircleDirectoryUnavailable(response.statusCode);
    }
    return response;
  }

  Uri _uri(String path, Map<String, String>? query) {
    final base = apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$base$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _object(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Surface only a generic availability error; never log response content.
    }
    throw const CircleDirectoryUnavailable();
  }

  Circle _circle(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const CircleDirectoryUnavailable();
    }
    try {
      return Circle.fromJson(value);
    } on FormatException {
      throw const CircleDirectoryUnavailable();
    }
  }
}
