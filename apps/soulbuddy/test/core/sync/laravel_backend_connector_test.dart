import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/sync/laravel_backend_connector.dart';
import 'package:soulbuddy/core/sync/sync_issue.dart';

void main() {
  test('fetches short-lived credentials from Laravel', () async {
    late http.Request captured;
    final connector = LaravelBackendConnector(
      apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
      powerSyncEndpoint: 'https://sync.soulbuddy.test',
      accessToken: () async => 'app-session-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'token': 'header.payload.signature', 'user_id': 'user-7'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final credentials = await connector.fetchCredentials();

    expect(captured.url.path, '/api/sync/token');
    expect(captured.headers['authorization'], 'Bearer app-session-token');
    expect(credentials?.endpoint, 'https://sync.soulbuddy.test');
    expect(credentials?.userId, 'user-7');
  });

  test('turns a PowerSync transaction into one Laravel batch', () async {
    Map<String, dynamic>? payload;
    var completed = false;
    final connector = LaravelBackendConnector(
      apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
      powerSyncEndpoint: 'https://sync.soulbuddy.test',
      accessToken: () async => 'token',
      client: MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'accepted': 1, 'rejected': 0}), 200);
      }),
    );
    final transaction = CrudTransaction(
      transactionId: 42,
      crud: [
        CrudEntry(
          9,
          UpdateType.put,
          'encounters',
          '0198a000-0000-7000-8000-000000000002',
          42,
          {
            'title': 'Private encounter title',
            'body': 'Private encounter body',
            'occurred_on': '2026-08-10',
            'is_altar': 0,
            'current_revision_id': '0198a000-0000-7000-8000-000000000003',
          },
        ),
      ],
      complete: ({writeCheckpoint}) async => completed = true,
    );

    await connector.uploadTransaction(transaction);

    expect(payload?['operations'], hasLength(1));
    expect(payload?['operations'][0]['type'], 'put');
    expect(payload?['operations'][0]['operation_id'], isNotEmpty);
    expect(completed, isTrue);
  });

  test('keeps a failed transaction pending after a transient response', () async {
    var completed = false;
    final connector = _connectorReturning(503);
    final transaction = _transaction(() => completed = true);

    await expectLater(
      connector.uploadTransaction(transaction),
      throwsA(isA<LaravelSyncUnavailable>()),
    );

    expect(completed, isFalse);
  });

  test('records a rejection and completes so later writes can continue', () async {
    var completed = false;
    final issues = <SyncIssue>[];
    final connector = _connectorReturning(
      200,
      body: {'accepted': 0, 'rejected': 1, 'code': 'forbidden'},
    );

    await connector.uploadTransaction(
      _transaction(() => completed = true),
      recordIssue: (issue) async => issues.add(issue),
    );

    expect(completed, isTrue);
    expect(issues.single.code, 'forbidden');
    expect(issues.single.message, isNot(contains('Private')));
  });
}

LaravelBackendConnector _connectorReturning(
  int status, {
  Map<String, dynamic> body = const {},
}) {
  return LaravelBackendConnector(
    apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
    powerSyncEndpoint: 'https://sync.soulbuddy.test',
    accessToken: () async => 'token',
    client: MockClient(
      (request) async => http.Response(jsonEncode(body), status),
    ),
  );
}

CrudTransaction _transaction(void Function() onComplete) {
  return CrudTransaction(
    transactionId: 7,
    crud: [
      CrudEntry(
        1,
        UpdateType.patch,
        'encounters',
        '0198a000-0000-7000-8000-000000000002',
        7,
        {'title': 'Private title'},
      ),
    ],
    complete: ({writeCheckpoint}) async => onComplete(),
  );
}
