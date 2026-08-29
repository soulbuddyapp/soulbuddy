import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/core/config/app_config.dart';
import 'package:soulbuddy/features/prayers/application/prayer_generation_dispatcher.dart';
import 'package:soulbuddy/features/prayers/data/laravel_prayer_draft_api.dart';
import 'package:soulbuddy/features/prayers/data/prayer_draft_api.dart';
import 'package:soulbuddy/features/prayers/data/prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';

void main() {
  test('prayer generation and request creation are permanently disabled', () {
    expect(AppConfig.prayerGenerationEnabled, isFalse);
    expect(AppConfig.prayerRequestCreationEnabled, isFalse);
  });

  test('local kill switch never calls the prayer draft API', () async {
    final now = DateTime.utc(2026, 8, 28, 1);
    final repository = _KillSwitchRepository(_queuedRequest(now));
    final api = _CountingPrayerDraftApi();
    final dispatcher = PrayerGenerationDispatcher(
      repository: repository,
      api: api,
      now: () => now,
      generationEnabled: false,
    );

    await dispatcher.dispatch(repository.request.id);

    expect(repository.claimed, isTrue);
    expect(repository.failureCode, 'generation_disabled');
    expect(api.generateCalls, 0);
  });

  test('server kill switch is terminal rather than retryable', () async {
    final api = LaravelPrayerDraftApi(
      apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
      accessToken: () async => 'token',
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'code': 'generation_disabled'}), 503),
      ),
    );

    await expectLater(
      api.generate(
        _queuedRequest(DateTime.utc(2026, 8, 28, 1)),
        const [],
        'attempt-1',
      ),
      throwsA(isA<PrayerDraftGenerationDisabled>()),
    );
  });
}

PrayerGenerationRequest _queuedRequest(DateTime now) => PrayerGenerationRequest(
  id: 'request-1',
  ownerId: 'owner-1',
  style: PrayerStyle.situational,
  reach: PrayerReach.personal,
  grounding: PrayerGrounding.generalChristian,
  languagePreference: PrayerLanguagePreference.christian,
  purpose: PrayerPurpose.guidance,
  requestText: 'Give me wisdom for the next faithful step.',
  beneficiaryChoice: 'me',
  surrenderChoice: 'all',
  responsibilityChoice: 'act_faithfully',
  alignmentChoice: 'no_conflict_seen',
  status: PrayerGenerationStatus.queued,
  consentedProvider: 'deepseek',
  consentedDisclosureVersion: 'deepseek-1',
  providerDisclosureVersion: 'deepseek-1',
  attemptCount: 0,
  contexts: const [],
  createdAt: now,
  updatedAt: now,
);

class _CountingPrayerDraftApi implements PrayerDraftApi {
  var generateCalls = 0;

  @override
  Future<PrayerGeneratedDraft> generate(
    PrayerGenerationRequest request,
    List<PrayerGenerationContext> contexts,
    String attemptId,
  ) async {
    generateCalls++;
    throw StateError('generate must not run while disabled');
  }

  @override
  Future<void> acknowledge(String attemptId) async {
    throw StateError('acknowledge must not run while disabled');
  }
}

class _KillSwitchRepository implements PrayerGenerationRepository {
  _KillSwitchRepository(this.request);

  final PrayerGenerationRequest request;
  bool claimed = false;
  String? failureCode;

  @override
  Stream<PrayerGenerationRequest?> watch(String id) => Stream.value(request);

  @override
  Stream<List<PrayerGenerationRequest>> watchPending() =>
      Stream.value([request]);

  @override
  Future<bool> claim(String requestId, String attemptId, DateTime now) async {
    claimed = true;
    return true;
  }

  @override
  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  ) async {
    this.failureCode = failureCode;
  }

  @override
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    PrayerLanguagePreference? languagePreference,
    required String requestText,
  }) async => throw UnsupportedError('not used');

  @override
  Future<void> update(PrayerGenerationRequest request) async =>
      throw UnsupportedError('not used');

  @override
  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  ) async => throw UnsupportedError('not used');

  @override
  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  }) async => throw UnsupportedError('not used');

  @override
  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  ) async => throw UnsupportedError('not used');

  @override
  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  }) async => throw UnsupportedError('not used');
}
