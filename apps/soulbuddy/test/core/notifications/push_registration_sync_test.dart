import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/core/notifications/push_registration_sync.dart';

void main() {
  test('a timed-out registration aborts its HTTP request before retry', () {
    fakeAsync((clock) {
      var aborted = false;
      final sync = createSync(
        client: MockClient.streaming((request, body) async {
          await body.toBytes();
          final response = Completer<http.StreamedResponse>();
          if (request is http.Abortable) {
            request.abortTrigger?.then((_) {
              aborted = true;
              response.completeError(http.RequestAbortedException());
            });
          }
          return response.future;
        }),
      );
      sync.synchronize();
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 15));
      clock.flushMicrotasks();
      expect(aborted, isTrue);
      expect(sync.state, PushSyncState.pending);
      sync.dispose();
    });
  });

  test('disposal during token fetch prevents session refresh', () async {
    final token = Completer<String?>();
    final tokenRequested = Completer<void>();
    var refreshes = 0;
    final sync = createSync(
      token: () {
        tokenRequested.complete();
        return token.future;
      },
      session: () async => null,
      refreshSession: () async {
        refreshes++;
      },
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    final pending = sync.synchronize();
    await tokenRequested.future;
    sync.dispose();
    token.complete('late-token');
    await pending;
    expect(refreshes, 0);
  });

  test(
    'token refresh during a request is serialized and registers the new token',
    () async {
      var token = 'old-token';
      final first = Completer<http.Response>();
      final started = Completer<void>();
      final registered = <String>[];
      final sync = createSync(
        token: () async => token,
        client: MockClient((request) async {
          registered.add(jsonDecode(request.body)['push_token'] as String);
          if (registered.length == 1) {
            started.complete();
            return first.future;
          }
          return http.Response('{"registered":true}', 200);
        }),
      );
      addTearDown(sync.dispose);
      final initial = sync.synchronize();
      await started.future;
      token = 'new-token';
      final refreshed = sync.synchronize();
      first.complete(http.Response('{"registered":true}', 200));
      await Future.wait([initial, refreshed]);
      expect(registered, ['old-token', 'new-token']);
      expect(sync.state, PushSyncState.registered);
    },
  );

  test(
    'transient Firebase startup failure retries and registers the token',
    () {
      fakeAsync((clock) {
        var reads = 0;
        final sync = createSync(
          token: () async {
            if (++reads == 1) throw Exception('SDK unavailable');
            return 'recovered-token';
          },
          client: MockClient(
            (_) async => http.Response('{"registered":true}', 200),
          ),
        );
        sync.synchronize();
        clock.flushMicrotasks();
        expect(sync.state, PushSyncState.pending);
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
        expect(sync.state, PushSyncState.registered);
        sync.dispose();
      });
    },
  );

  test(
    'an unavailable Firebase token never clears an existing registration',
    () async {
      var requests = 0;
      final sync = createSync(
        token: () async => null,
        client: MockClient((request) async {
          requests++;
          return http.Response('{"registered":false}', 200);
        }),
      );
      addTearDown(sync.dispose);
      await sync.synchronize();
      expect(requests, 0);
      expect(sync.state, PushSyncState.pending);
    },
  );

  test('failed registration retries without reopening the app', () {
    fakeAsync((clock) {
      var requests = 0;
      final sync = createSync(
        client: MockClient((request) async {
          requests++;
          return requests == 1
              ? http.Response('unavailable', 503)
              : http.Response('{"registered":true}', 200);
        }),
      );
      sync.synchronize();
      clock.flushMicrotasks();
      expect(sync.state, PushSyncState.pending);
      clock.elapse(const Duration(seconds: 5));
      clock.flushMicrotasks();
      expect(requests, 2);
      expect(sync.state, PushSyncState.registered);
      sync.dispose();
    });
  });

  test(
    'missing installation session is repaired after an offline first launch',
    () async {
      String? session;
      final sync = createSync(
        session: () async => session,
        refreshSession: () async => session = 'fresh-session',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer fresh-session');
          return http.Response('{"registered":true}', 200);
        }),
      );
      addTearDown(sync.dispose);
      await sync.synchronize();
      expect(sync.state, PushSyncState.registered);
    },
  );

  test(
    'expired authentication is refreshed before retrying registration',
    () async {
      var session = 'expired';
      var requests = 0;
      final sync = createSync(
        session: () async => session,
        refreshSession: () async => session = 'fresh',
        client: MockClient((request) async {
          requests++;
          if (request.headers['authorization'] == 'Bearer expired') {
            return http.Response('{}', 401);
          }
          return http.Response('{"registered":true}', 200);
        }),
      );
      addTearDown(sync.dispose);
      await sync.synchronize();
      expect(requests, 2);
      expect(sync.state, PushSyncState.registered);
    },
  );

  test(
    'explicitly denied permission clears registration without fetching token',
    () async {
      final sync = createSync(
        permission: () async => PushPermission.denied,
        token: () async => throw StateError('must not fetch token'),
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['push_token'], isNull);
          return http.Response('{"registered":false}', 200);
        }),
      );
      addTearDown(sync.dispose);
      await sync.synchronize();
      expect(sync.state, PushSyncState.permissionDenied);
    },
  );

  test('undetermined permission does not delete registration', () async {
    final sync = createSync(
      permission: () async => PushPermission.undetermined,
      client: MockClient((request) async => throw StateError('must not post')),
    );
    addTearDown(sync.dispose);
    await sync.synchronize();
    expect(sync.state, PushSyncState.pending);
  });

  test('pause cancels foreground retry and resume repairs registration', () {
    fakeAsync((clock) {
      var requests = 0;
      final sync = createSync(
        client: MockClient((request) async {
          requests++;
          return http.Response('{}', 503);
        }),
      );
      sync.synchronize();
      clock.flushMicrotasks();
      sync.pause();
      clock.elapse(const Duration(minutes: 10));
      clock.flushMicrotasks();
      expect(requests, 1);
      sync.resume();
      clock.flushMicrotasks();
      expect(requests, 2);
      sync.dispose();
      clock.elapse(const Duration(minutes: 10));
      clock.flushMicrotasks();
      expect(requests, 2);
    });
  });

  test('a successful HTTP response must confirm the registration', () async {
    final sync = createSync(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(sync.dispose);
    await sync.synchronize();
    expect(sync.state, PushSyncState.pending);
  });
}

PushRegistrationSync createSync({
  required http.Client client,
  Future<String?> Function()? token,
  Future<String?> Function()? session,
  Future<void> Function()? refreshSession,
  Future<PushPermission> Function()? permission,
}) => PushRegistrationSync(
  baseUri: Uri.parse('https://example.test'),
  deviceId: 'test-device',
  client: client,
  readPushToken: token ?? () async => 'firebase-token',
  readSession: session ?? () async => 'session',
  refreshSession: refreshSession ?? () async {},
  readPermission: permission ?? () async => PushPermission.allowed,
  readTimeZone: () async => 'Africa/Lagos',
);
