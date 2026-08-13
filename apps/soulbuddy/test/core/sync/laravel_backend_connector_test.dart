import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/sync/laravel_backend_connector.dart';
import 'package:soulbuddy/core/sync/sync_issue.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test('fetches short-lived credentials from Laravel', () async {
    late http.Request captured;
    final connector = LaravelBackendConnector(
      apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
      powerSyncEndpoint: 'https://sync.soulbuddy.test',
      installationId: 'installation-1',
      accessToken: () async => 'app-session-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'token': 'header.payload.signature',
            'user_id': 'user-7',
          }),
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
      installationId: 'installation-1',
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

  test(
    'bounded direct flush drains pending mutations without PowerSync',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'soulbuddy-direct-flush-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = await openTestDatabase('${directory.path}/soulbuddy.db');
      addTearDown(database.close);
      await database.powersync.execute(
        '''
      INSERT INTO encounters(
        id, owner_id, title, body, occurred_on, is_altar,
        current_revision_id, created_at, updated_at, archived_at,
        memory_type, sensitive, recall_enabled, recall_paused,
        recall_interval_days
      ) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, NULL, 'deed', 0, 1, 0, 7)
      ''',
        [
          '0198a000-0000-7000-8000-000000000002',
          '0198a000-0000-7000-8000-000000000001',
          'Remember',
          'The Lord helped me.',
          '2026-08-13',
          '0198a000-0000-7000-8000-000000000003',
          '2026-08-13T10:00:00Z',
          '2026-08-13T10:00:00Z',
        ],
      );
      var requests = 0;
      final connector = LaravelBackendConnector(
        apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
        powerSyncEndpoint: '',
        installationId: 'installation-1',
        accessToken: () async => 'token',
        client: MockClient((request) async {
          requests++;
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'accepted': (payload['operations'] as List).length,
              'rejected': 0,
            }),
            200,
          );
        }),
      );

      await connector.flushPending(database.powersync);

      expect(requests, 1);
      expect(await database.powersync.getNextCrudTransaction(), isNull);
    },
  );

  test(
    'changed content cannot reuse an operation id after a local rebuild',
    () async {
      final operationIds = <String>[];
      final connector = LaravelBackendConnector(
        apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
        powerSyncEndpoint: 'https://sync.soulbuddy.test',
        installationId: 'installation-1',
        accessToken: () async => 'token',
        client: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final operations = payload['operations'] as List<dynamic>;
          operationIds.add(
            (operations.single as Map<String, dynamic>)['operation_id']
                as String,
          );
          return http.Response(jsonEncode({'accepted': 1, 'rejected': 0}), 200);
        }),
      );

      await connector.uploadTransaction(_transactionWithTitle('First title'));
      await connector.uploadTransaction(_transactionWithTitle('Changed title'));

      expect(operationIds[0], isNot(operationIds[1]));
    },
  );

  test(
    'keeps a failed transaction pending after a transient response',
    () async {
      var completed = false;
      final connector = _connectorReturning(503);
      final transaction = _transaction(() => completed = true);

      await expectLater(
        connector.uploadTransaction(transaction),
        throwsA(isA<LaravelSyncUnavailable>()),
      );

      expect(completed, isFalse);
    },
  );

  test(
    'records a rejection and completes so later writes can continue',
    () async {
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
    },
  );

  test(
    'keeps a transaction pending when a 200 response is malformed',
    () async {
      var completed = false;
      final connector = _connectorReturning(200, body: {'message': 'ok'});

      await expectLater(
        connector.uploadTransaction(_transaction(() => completed = true)),
        throwsA(isA<LaravelSyncUnavailable>()),
      );

      expect(completed, isFalse);
    },
  );

  test(
    'records a permanent request rejection without poisoning the queue',
    () async {
      var completed = false;
      final issues = <SyncIssue>[];
      final connector = _connectorReturning(
        422,
        body: {'message': 'Private title was invalid'},
      );

      await connector.uploadTransaction(
        _transaction(() => completed = true),
        recordIssue: (issue) async => issues.add(issue),
      );

      expect(completed, isTrue);
      expect(issues.single.code, 'http_422');
      expect(issues.single.message, isNot(contains('Private')));
    },
  );
}

LaravelBackendConnector _connectorReturning(
  int status, {
  Map<String, dynamic> body = const {},
}) {
  return LaravelBackendConnector(
    apiBaseUri: Uri.parse('https://api.soulbuddy.test'),
    powerSyncEndpoint: 'https://sync.soulbuddy.test',
    installationId: 'installation-1',
    accessToken: () async => 'token',
    client: MockClient(
      (request) async => http.Response(jsonEncode(body), status),
    ),
  );
}

CrudTransaction _transaction(void Function() onComplete) {
  return _transactionWithTitle('Private title', onComplete: onComplete);
}

CrudTransaction _transactionWithTitle(
  String title, {
  void Function()? onComplete,
}) {
  return CrudTransaction(
    transactionId: 7,
    crud: [
      CrudEntry(
        1,
        UpdateType.patch,
        'encounters',
        '0198a000-0000-7000-8000-000000000002',
        7,
        {'title': title},
      ),
    ],
    complete: ({writeCheckpoint}) async => onComplete?.call(),
  );
}
