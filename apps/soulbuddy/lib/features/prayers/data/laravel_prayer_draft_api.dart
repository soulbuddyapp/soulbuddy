import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/prayer_generation_request.dart';
import 'prayer_draft_api.dart';

class LaravelPrayerDraftApi implements PrayerDraftApi {
  LaravelPrayerDraftApi({
    required this.apiBaseUri,
    required this.accessToken,
    required this.client,
    this.timeout = const Duration(seconds: 20),
  });

  final Uri apiBaseUri;
  final Future<String?> Function() accessToken;
  final http.Client client;
  final Duration timeout;

  @override
  Future<PrayerGeneratedDraft> generate(
    PrayerGenerationRequest request,
    List<PrayerGenerationContext> contexts,
    String attemptId,
  ) async {
    final token = await _requiredToken();
    final disclosureVersion = request.consentedDisclosureVersion;
    if (disclosureVersion == null || disclosureVersion.isEmpty) {
      throw const PrayerDraftInvalidRequest();
    }
    final response = await _send(
      client.post(
        _apiUri('/api/prayer-drafts'),
        headers: _headers(token),
        body: jsonEncode({
          'attempt_id': attemptId,
          'disclosure_version': disclosureVersion,
          'consent': true,
          'style': request.style.wireValue,
          'reach': request.reach.wireValue,
          'grounding': request.grounding.wireValue,
          'language_preference': request.languagePreference.wireValue,
          'purpose': request.purpose.wireValue,
          'request_text': request.requestText,
          'choices': {
            'beneficiary': request.beneficiaryChoice,
            'surrender': request.surrenderChoice,
            'responsibility': request.responsibilityChoice,
            'alignment': request.alignmentChoice,
          },
          'contexts': contexts.map(_contextPayload).toList(growable: false),
        }),
      ),
    );
    _throwForStatus(response);

    final payload = _decodeObject(response.body);
    final draft = payload['draft'];
    final responseAttemptId = payload['attempt_id'];
    final promptVersion = payload['prompt_version'];
    if (responseAttemptId != attemptId ||
        promptVersion is! String ||
        promptVersion.isEmpty ||
        draft is! Map<String, dynamic>) {
      throw const PrayerDraftNeedsAttention();
    }
    final keys = draft.keys.toList()..sort();
    final title = draft['title'];
    final body = draft['body'];
    final action = draft['action'];
    if (keys.join(',') != 'action,body,title' ||
        title is! String ||
        title.isEmpty ||
        body is! String ||
        body.isEmpty ||
        (action != null && action is! String)) {
      throw const PrayerDraftNeedsAttention();
    }

    return PrayerGeneratedDraft(
      title: title,
      body: body,
      action: action as String?,
      promptVersion: promptVersion,
    );
  }

  @override
  Future<void> acknowledge(String attemptId) async {
    final token = await _requiredToken();
    final response = await _send(
      client.delete(
        _apiUri('/api/prayer-drafts/$attemptId'),
        headers: _headers(token),
      ),
    );
    _throwForStatus(response);
  }

  Future<String> _requiredToken() async {
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const PrayerDraftSessionRequired();
    }
    return token;
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw const PrayerDraftUnavailable();
    } on http.ClientException {
      throw const PrayerDraftUnavailable();
    }
  }

  void _throwForStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw const PrayerDraftSessionRequired();
    }
    if (response.statusCode == 429) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      final bounded = seconds?.clamp(0, 600);
      throw PrayerDraftRateLimited(
        bounded == null ? null : Duration(seconds: bounded),
      );
    }
    if (response.statusCode == 502 &&
        _responseCode(response.body) == 'draft_needs_attention') {
      throw const PrayerDraftNeedsAttention();
    }
    if (response.statusCode >= 500) {
      throw const PrayerDraftUnavailable();
    }
    throw const PrayerDraftInvalidRequest();
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // The caller receives a content-free error.
    }
    throw const PrayerDraftNeedsAttention();
  }

  String? _responseCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['code'] is String) {
        return decoded['code'] as String;
      }
    } on FormatException {
      // Status mapping remains content-free.
    }
    return null;
  }

  Map<String, String> _headers(String token) => {
    'authorization': 'Bearer $token',
    'content-type': 'application/json',
    'accept': 'application/json',
  };

  Uri _apiUri(String path) {
    final normalized = apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$normalized$path');
  }
}

Map<String, dynamic> _contextPayload(PrayerGenerationContext context) {
  final payload = <String, dynamic>{
    'type': context.type.wireValue,
    'source_id': context.sourceId,
    'display_label': context.displayLabel,
    'excerpt_snapshot': context.excerptSnapshot,
  };
  if (context.type == PrayerContextType.scripture) {
    payload.addAll({
      'translation': context.translation,
      'book': context.book,
      'chapter': context.chapter,
      'first_verse': context.firstVerse,
      'last_verse': context.lastVerse,
    });
  }
  return payload;
}
