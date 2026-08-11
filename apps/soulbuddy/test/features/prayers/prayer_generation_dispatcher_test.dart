import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/prayers/application/prayer_generation_dispatcher.dart';
import 'package:soulbuddy/features/prayers/application/prayer_generation_worker.dart';
import 'package:soulbuddy/features/prayers/data/laravel_prayer_draft_api.dart';
import 'package:soulbuddy/features/prayers/data/prayer_draft_api.dart';
import 'package:soulbuddy/features/prayers/data/prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('PrayerGenerationDispatcher', () {
    late DateTime now;
    late _MemoryGenerationRepository repository;

    setUp(() {
      now = DateTime.utc(2026, 8, 11, 8);
      repository = _MemoryGenerationRepository(_queuedRequest(now));
    });

    test('stores the draft before acknowledging the server attempt', () async {
      final calls = <String>[];
      final api = _FakePrayerDraftApi(
        onGenerate: (_, _, _) async {
          calls.add('generate');
          return _generated;
        },
        onAcknowledge: (_) async {
          expect(repository.current.status, PrayerGenerationStatus.ready);
          calls.add('ack');
        },
      );

      await _dispatcher(repository, api, now).dispatch(repository.current.id);

      expect(calls, ['generate', 'ack']);
      expect(repository.current.status, PrayerGenerationStatus.ready);
      expect(repository.current.draftBody, _generated.body);
    });

    test('defers transient failures on the bounded schedule', () async {
      final api = _FakePrayerDraftApi(
        onGenerate: (_, _, _) async => throw const PrayerDraftUnavailable(),
      );

      await _dispatcher(repository, api, now).dispatch(repository.current.id);

      expect(repository.current.status, PrayerGenerationStatus.queued);
      expect(
        repository.current.nextAttemptAt,
        now.add(const Duration(seconds: 5)),
      );
      expect(repository.current.failureCode, 'temporarily_unavailable');
    });

    test('honors a longer provider Retry-After delay', () async {
      final api = _FakePrayerDraftApi(
        onGenerate: (_, _, _) async =>
            throw const PrayerDraftRateLimited(Duration(seconds: 45)),
      );

      await _dispatcher(repository, api, now).dispatch(repository.current.id);

      expect(
        repository.current.nextAttemptAt,
        now.add(const Duration(seconds: 45)),
      );
      expect(repository.current.failureCode, 'rate_limited');
    });

    test(
      'requires attention for missing sessions and invalid requests',
      () async {
        for (final entry in <(PrayerDraftApiException, String)>[
          (const PrayerDraftSessionRequired(), 'session_required'),
          (const PrayerDraftInvalidRequest(), 'request_invalid'),
          (const PrayerDraftNeedsAttention(), 'draft_needs_attention'),
        ]) {
          repository = _MemoryGenerationRepository(_queuedRequest(now));
          final api = _FakePrayerDraftApi(
            onGenerate: (_, _, _) async => throw entry.$1,
          );

          await _dispatcher(
            repository,
            api,
            now,
          ).dispatch(repository.current.id);

          expect(
            repository.current.status,
            PrayerGenerationStatus.needsAttention,
          );
          expect(repository.current.failureCode, entry.$2);
        }
      },
    );

    test('stops automatically after the fourth transient retry', () async {
      repository = _MemoryGenerationRepository(
        _queuedRequest(now, attemptCount: 4),
      );
      final api = _FakePrayerDraftApi(
        onGenerate: (_, _, _) async => throw const PrayerDraftUnavailable(),
      );

      await _dispatcher(repository, api, now).dispatch(repository.current.id);

      expect(repository.current.status, PrayerGenerationStatus.needsAttention);
      expect(repository.current.failureCode, 'temporarily_unavailable');
      expect(repository.current.nextAttemptAt, isNull);
    });

    test('does not generate twice when dispatch overlaps', () async {
      final release = Completer<void>();
      var generations = 0;
      final api = _FakePrayerDraftApi(
        onGenerate: (_, _, _) async {
          generations++;
          await release.future;
          return _generated;
        },
      );
      final dispatcher = _dispatcher(repository, api, now);

      final first = dispatcher.dispatch(repository.current.id);
      await Future<void>.delayed(Duration.zero);
      final second = dispatcher.dispatch(repository.current.id);
      release.complete();
      await Future.wait([first, second]);

      expect(generations, 1);
      expect(repository.current.status, PrayerGenerationStatus.ready);
    });

    test('keeps the local draft when acknowledgement fails', () async {
      final api = _FakePrayerDraftApi(
        onGenerate: (_, _, _) async => _generated,
        onAcknowledge: (_) async => throw const PrayerDraftUnavailable(),
      );

      await _dispatcher(repository, api, now).dispatch(repository.current.id);

      expect(repository.current.status, PrayerGenerationStatus.ready);
      expect(repository.current.draftTitle, _generated.title);
    });
  });

  group('LaravelPrayerDraftApi', () {
    test(
      'reads the session for every call and sends only allowed fields',
      () async {
        final tokens = ['first-token', 'second-token'];
        final requests = <http.Request>[];
        final api = LaravelPrayerDraftApi(
          apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
          accessToken: () async => tokens.removeAt(0),
          client: MockClient((request) async {
            requests.add(request);
            if (request.method == 'DELETE') return http.Response('', 204);
            return http.Response(
              jsonEncode({
                'attempt_id': 'attempt-1',
                'prompt_version': '1',
                'disclosure_version': 'deepseek-1',
                'draft': {
                  'title': _generated.title,
                  'body': _generated.body,
                  'action': _generated.action,
                },
              }),
              200,
            );
          }),
        );
        final request = _queuedRequest(DateTime.utc(2026, 8, 11, 8));

        await api.generate(request, request.contexts, 'attempt-1');
        await api.acknowledge('attempt-1');

        expect(requests[0].headers['authorization'], 'Bearer first-token');
        expect(requests[1].headers['authorization'], 'Bearer second-token');
        final payload = jsonDecode(requests[0].body) as Map<String, dynamic>;
        expect(payload.keys, {
          'attempt_id',
          'disclosure_version',
          'consent',
          'style',
          'reach',
          'grounding',
          'purpose',
          'request_text',
          'choices',
          'contexts',
        });
        expect(payload, isNot(contains('owner_id')));
      },
    );

    test('maps authentication and safe HTTP failures', () async {
      for (final entry in <(int, Type)>[
        (401, PrayerDraftSessionRequired),
        (422, PrayerDraftInvalidRequest),
        (429, PrayerDraftRateLimited),
        (502, PrayerDraftUnavailable),
        (503, PrayerDraftUnavailable),
      ]) {
        final api = _apiReturning(entry.$1);
        await expectLater(
          api.generate(
            _queuedRequest(DateTime.utc(2026, 8, 11, 8)),
            const [],
            'attempt-1',
          ),
          throwsA(predicate((error) => error.runtimeType == entry.$2)),
        );
      }
    });

    test('maps only the explicit guarded-draft failure to attention', () async {
      final api = _apiReturning(502, code: 'draft_needs_attention');

      await expectLater(
        api.generate(
          _queuedRequest(DateTime.utc(2026, 8, 11, 8)),
          const [],
          'attempt-1',
        ),
        throwsA(isA<PrayerDraftNeedsAttention>()),
      );
    });

    test(
      'maps timeout and malformed success without exposing content',
      () async {
        final timeoutApi = LaravelPrayerDraftApi(
          apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
          accessToken: () async => 'token',
          timeout: Duration.zero,
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return http.Response('{}', 200);
          }),
        );
        final malformedApi = LaravelPrayerDraftApi(
          apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
          accessToken: () async => 'token',
          client: MockClient((_) async => http.Response('private body', 200)),
        );

        await expectLater(
          timeoutApi.generate(
            _queuedRequest(DateTime.utc(2026, 8, 11, 8)),
            const [],
            'attempt-1',
          ),
          throwsA(isA<PrayerDraftUnavailable>()),
        );
        await expectLater(
          malformedApi.generate(
            _queuedRequest(DateTime.utc(2026, 8, 11, 8)),
            const [],
            'attempt-1',
          ),
          throwsA(
            isA<PrayerDraftNeedsAttention>().having(
              (error) => error.toString(),
              'safe message',
              isNot(contains('private body')),
            ),
          ),
        );
      },
    );
  });

  group('PrayerGenerationWorker', () {
    testWidgets('wakes for the next bounded retry time', (tester) async {
      var now = DateTime.utc(2026, 8, 11, 8);
      final repository = _MemoryGenerationRepository(
        _queuedRequest(now, nextAttemptAt: now.add(const Duration(seconds: 5))),
      );
      var generations = 0;
      final dispatcher = PrayerGenerationDispatcher(
        repository: repository,
        api: _FakePrayerDraftApi(
          onGenerate: (_, _, _) async {
            generations++;
            return _generated;
          },
        ),
        now: () => now,
      );
      final worker = PrayerGenerationWorker(
        repository: repository,
        dispatcher: dispatcher,
        now: () => now,
      )..start();
      addTearDown(worker.dispose);

      now = now.add(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      expect(generations, 0);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(generations, 1);
    });

    testWidgets('resamples immediately when the app resumes', (tester) async {
      var now = DateTime.utc(2026, 8, 11, 8);
      final repository = _MemoryGenerationRepository(
        _queuedRequest(now, nextAttemptAt: now.add(const Duration(hours: 1))),
      );
      var generations = 0;
      final dispatcher = PrayerGenerationDispatcher(
        repository: repository,
        api: _FakePrayerDraftApi(
          onGenerate: (_, _, _) async {
            generations++;
            return _generated;
          },
        ),
        now: () => now,
      );
      final worker = PrayerGenerationWorker(
        repository: repository,
        dispatcher: dispatcher,
        now: () => now,
      )..start();
      addTearDown(worker.dispose);
      await tester.pump();

      now = now.add(const Duration(hours: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(generations, 1);
    });
  });
}

PrayerGenerationDispatcher _dispatcher(
  PrayerGenerationRepository repository,
  PrayerDraftApi api,
  DateTime now,
) => PrayerGenerationDispatcher(
  repository: repository,
  api: api,
  now: () => now,
  uuid: const Uuid(),
);

LaravelPrayerDraftApi _apiReturning(int status, {String? code}) =>
    LaravelPrayerDraftApi(
      apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
      accessToken: () async => 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'code': code ?? (status == 429 ? 'rate_limited' : null)}),
          status,
          headers: status == 429 ? {'retry-after': '17'} : {},
        ),
      ),
    );

const _generated = PrayerGeneratedDraft(
  title: 'For faithful wisdom',
  body:
      'Father, give us wisdom as we face this moment. Keep us truthful, patient, and ready to listen. Guard us from fear, pride, and haste. Help us consider everyone affected, receive correction with humility, and act with love. We entrust the outcome, timing, and way forward to you. Strengthen us to do what is faithful, repair any harm, and serve one another in peace. Keep our hearts near you and our steps honest. Amen.',
  action: 'Listen carefully before choosing a response.',
  promptVersion: '1',
);

PrayerGenerationRequest _queuedRequest(
  DateTime now, {
  int attemptCount = 0,
  DateTime? nextAttemptAt,
}) {
  return PrayerGenerationRequest(
    id: 'request-1',
    ownerId: 'owner-1',
    style: PrayerStyle.situational,
    reach: PrayerReach.encompassing,
    grounding: PrayerGrounding.generalChristian,
    purpose: PrayerPurpose.family,
    requestText: 'Give our family wisdom in this decision.',
    beneficiaryChoice: 'household_family',
    surrenderChoice: 'all',
    responsibilityChoice: 'act_faithfully',
    alignmentChoice: 'no_conflict_seen',
    status: PrayerGenerationStatus.queued,
    consentedProvider: 'deepseek',
    consentedDisclosureVersion: 'deepseek-1',
    providerDisclosureVersion: 'deepseek-1',
    nextAttemptAt: nextAttemptAt,
    attemptCount: attemptCount,
    contexts: const [],
    createdAt: now,
    updatedAt: now,
  );
}

class _FakePrayerDraftApi implements PrayerDraftApi {
  _FakePrayerDraftApi({required this.onGenerate, this.onAcknowledge});

  final Future<PrayerGeneratedDraft> Function(
    PrayerGenerationRequest,
    List<PrayerGenerationContext>,
    String,
  )
  onGenerate;
  final Future<void> Function(String)? onAcknowledge;

  @override
  Future<PrayerGeneratedDraft> generate(
    PrayerGenerationRequest request,
    List<PrayerGenerationContext> contexts,
    String attemptId,
  ) => onGenerate(request, contexts, attemptId);

  @override
  Future<void> acknowledge(String attemptId) =>
      onAcknowledge?.call(attemptId) ?? Future<void>.value();
}

class _MemoryGenerationRepository implements PrayerGenerationRepository {
  _MemoryGenerationRepository(this.current);

  PrayerGenerationRequest current;

  @override
  Stream<PrayerGenerationRequest?> watch(String id) => Stream.value(current);

  @override
  Stream<List<PrayerGenerationRequest>> watchPending() =>
      Stream.value([current]);

  @override
  Future<bool> claim(String requestId, String attemptId, DateTime now) async {
    if (current.status != PrayerGenerationStatus.queued) return false;
    current = _copy(
      status: PrayerGenerationStatus.generating,
      activeAttemptId: attemptId,
      attemptStartedAt: now,
      attemptCount: current.attemptCount + 1,
      lastAttemptAt: now,
    );
    return true;
  }

  @override
  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  ) async {
    if (current.activeAttemptId != attemptId) return;
    current = _copy(
      status: PrayerGenerationStatus.ready,
      draft: draft,
      clearAttempt: true,
    );
  }

  @override
  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  }) async {
    if (current.activeAttemptId != attemptId) return;
    current = _copy(
      status: PrayerGenerationStatus.queued,
      nextAttemptAt: nextAttemptAt,
      failureCode: failureCode,
      clearAttempt: true,
    );
  }

  @override
  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  ) async {
    if (current.activeAttemptId != attemptId) return;
    current = _copy(
      status: PrayerGenerationStatus.needsAttention,
      failureCode: failureCode,
      clearAttempt: true,
    );
  }

  PrayerGenerationRequest _copy({
    required PrayerGenerationStatus status,
    String? activeAttemptId,
    DateTime? attemptStartedAt,
    DateTime? nextAttemptAt,
    int? attemptCount,
    DateTime? lastAttemptAt,
    String? failureCode,
    PrayerGeneratedDraft? draft,
    bool clearAttempt = false,
  }) => PrayerGenerationRequest(
    id: current.id,
    ownerId: current.ownerId,
    style: current.style,
    reach: current.reach,
    grounding: current.grounding,
    purpose: current.purpose,
    requestText: current.requestText,
    beneficiaryChoice: current.beneficiaryChoice,
    surrenderChoice: current.surrenderChoice,
    responsibilityChoice: current.responsibilityChoice,
    alignmentChoice: current.alignmentChoice,
    status: status,
    draftTitle: draft?.title ?? current.draftTitle,
    draftBody: draft?.body ?? current.draftBody,
    draftAction: draft?.action ?? current.draftAction,
    generatedTitle: draft?.title ?? current.generatedTitle,
    generatedBody: draft?.body ?? current.generatedBody,
    generatedAction: draft?.action ?? current.generatedAction,
    promptVersion: draft?.promptVersion ?? current.promptVersion,
    providerDisclosureVersion: current.providerDisclosureVersion,
    consentedProvider: current.consentedProvider,
    consentedDisclosureVersion: current.consentedDisclosureVersion,
    activeAttemptId: clearAttempt ? null : activeAttemptId,
    attemptStartedAt: clearAttempt ? null : attemptStartedAt,
    nextAttemptAt: nextAttemptAt,
    attemptCount: attemptCount ?? current.attemptCount,
    lastAttemptAt: lastAttemptAt ?? current.lastAttemptAt,
    failureCode: failureCode,
    contexts: current.contexts,
    createdAt: current.createdAt,
    updatedAt: current.updatedAt,
  );

  @override
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    required String requestText,
  }) => throw UnimplementedError();

  @override
  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  }) => throw UnimplementedError();

  @override
  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  ) => throw UnimplementedError();

  @override
  Future<void> update(PrayerGenerationRequest request) =>
      throw UnimplementedError();
}
