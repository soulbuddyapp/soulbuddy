import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soulbuddy/core/config/app_config.dart';
import 'package:soulbuddy/core/sync/laravel_backend_connector.dart';
import 'package:soulbuddy/core/sync/saved_records_upload_pump.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory directory;
  late _RecordingClient client;

  group('which direction is available', () {
    test('a reachable boundary uploads even without a sync service', () {
      expect(
        resolveSyncMode(uploadConfigured: true, downloadConfigured: false),
        SyncMode.uploadOnly,
      );
    });

    test('a sync service takes both directions', () {
      expect(
        resolveSyncMode(uploadConfigured: true, downloadConfigured: true),
        SyncMode.download,
      );
    });

    test('no boundary leaves records on the device', () {
      expect(
        resolveSyncMode(uploadConfigured: false, downloadConfigured: false),
        SyncMode.localOnly,
      );
    });

    test('a sync service alone cannot serve records', () {
      expect(
        resolveSyncMode(uploadConfigured: false, downloadConfigured: true),
        SyncMode.localOnly,
      );
    });
  });

  group('missing configuration is reportable', () {
    test('names every define this build lacks', () {
      // A test run compiles without defines, which is exactly the build that
      // silently recorded no activity: no upload, no events, no warning.
      expect(AppConfig.missingConfiguration(), [
        'SOULBUDDY_API_URL',
        'SOULBUDDY_POWERSYNC_URL',
      ]);
    });

    test('a build without defines uploads nothing', () {
      expect(
        resolveSyncMode(
          uploadConfigured: AppConfig.apiBaseUrl.isNotEmpty,
          downloadConfigured: AppConfig.powerSyncUrl.isNotEmpty,
        ),
        SyncMode.localOnly,
        reason: 'no boundary means no pump, so records stay on the device',
      );
    });
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('soulbuddy-upload-pump-');
    client = _RecordingClient();
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  Future<_Harness> openHarness({
    List<int>? failWith,
    bool reject = false,
  }) async {
    final database = await openTestDatabase('${directory.path}/soulbuddy.db');
    final connector = LaravelBackendConnector(
      apiBaseUri: Uri.parse('https://example.test'),
      powerSyncEndpoint: '',
      installationId: 'installation-1',
      accessToken: () async => 'session-token',
      client: client,
    );
    client.reject = reject;
    client.responses.addAll(
      failWith == null
          ? List<int>.filled(40, 200)
          : [...failWith, ...List<int>.filled(40, 200)],
    );
    return _Harness(database, connector);
  }

  test('sends a saved record that was never uploaded', () async {
    final harness = await openHarness();
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final uploaded = await SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
    ).drain();

    expect(uploaded, 1);
    expect(client.posts, hasLength(1));
    final body = jsonDecode(client.posts.single.body) as Map<String, dynamic>;
    final operations = body['operations'] as List<dynamic>;
    expect(operations, hasLength(1));
    expect(
      (operations.single as Map<String, dynamic>)['table'],
      'today_prayers',
    );
    expect(client.posts.single.url.path, '/api/sync/mutations');
  });

  test('a sent record leaves the queue so it is not sent again', () async {
    final harness = await openHarness();
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
    );
    expect(await pump.drain(), 1);
    expect(await pump.drain(), 0);
    expect(client.posts, hasLength(1));
  });

  test(
    'a record waiting before startup is sent without a fresh write',
    () async {
      final harness = await openHarness();
      addTearDown(harness.database.close);
      await _selectTodayPrayer(harness);

      final pump = SavedRecordsUploadPump(
        database: harness.database.powersync,
        connector: harness.connector,
        idleInterval: const Duration(milliseconds: 10),
      )..start();
      addTearDown(pump.stop);

      await _waitFor(() => client.posts.isNotEmpty);
      expect(client.posts, hasLength(1));
      expect(pump.isRunning, isTrue);
    },
  );

  test('a failure keeps the record and reports it, then recovers', () async {
    final harness = await openHarness(failWith: [503]);
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final reported = <Object>[];
    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
      retryDelay: const Duration(milliseconds: 10),
      onError: (error, _) => reported.add(error),
    )..start();
    addTearDown(pump.stop);

    await _waitFor(() => client.posts.length >= 2);
    expect(reported, isNotEmpty);
    expect(reported.first, isA<LaravelSyncUnavailable>());
  });

  test('a failure keeps the record queued for the next pass', () async {
    final harness = await openHarness(failWith: [500]);
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
    );

    await expectLater(pump.drain(), throwsA(isA<LaravelSyncUnavailable>()));
    expect(
      await harness.database.powersync.getNextCrudTransaction(),
      isNotNull,
      reason: 'an unsent record must stay queued, not be dropped',
    );
  });

  test('a resend after a failure reuses the operation id', () async {
    final harness = await openHarness(failWith: [500]);
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
    );
    await expectLater(pump.drain(), throwsA(isA<LaravelSyncUnavailable>()));
    await pump.drain();

    String operationId(http.Request request) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final operations = body['operations'] as List<dynamic>;
      return (operations.single as Map<String, dynamic>)['operation_id']
          as String;
    }

    expect(
      operationId(client.posts.last),
      operationId(client.posts.first),
      reason: 'a repeated send must be recognisable as the same record',
    );
  });

  test('stopping leaves a record for the next start', () async {
    final harness = await openHarness(failWith: [500]);
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
      retryDelay: const Duration(milliseconds: 10),
    )..start();

    await pump.stop();
    expect(pump.isRunning, isFalse);
    expect(
      await harness.database.powersync.getNextCrudTransaction(),
      isNotNull,
    );
  });

  test('a record the boundary refuses leaves a note, not silence', () async {
    // The boundary answers 200 with rejected=1, so the queue clears either way.
    final harness = await openHarness(reject: true);
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
    );
    expect(await pump.drain(), 1);

    final issues = await harness.database.powersync.getAll(
      'SELECT record_type, code FROM sync_issues',
    );
    expect(
      issues,
      hasLength(1),
      reason: 'a refused record must leave evidence it was refused',
    );
    expect(issues.single['record_type'], 'today_prayers');
    expect(issues.single['code'], 'invalid_prayer');
  });

  test('an accepted record leaves no note', () async {
    final harness = await openHarness();
    addTearDown(harness.database.close);
    await _selectTodayPrayer(harness);

    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
    );
    await pump.drain();

    expect(
      await harness.database.powersync.getAll('SELECT * FROM sync_issues'),
      isEmpty,
    );
  });

  test('a record saved while idle is sent without another write', () async {
    final harness = await openHarness();
    addTearDown(harness.database.close);

    final pump = SavedRecordsUploadPump(
      database: harness.database.powersync,
      connector: harness.connector,
      idleInterval: const Duration(milliseconds: 20),
    )..start();
    addTearDown(pump.stop);

    await _waitFor(() => client.posts.isNotEmpty == false);
    await _selectTodayPrayer(harness);

    await _waitFor(() => client.posts.isNotEmpty);
    expect(client.posts, hasLength(1));
  });
}

class _Harness {
  _Harness(this.database, this.connector);

  final dynamic database;
  final LaravelBackendConnector connector;
}

Future<void> _selectTodayPrayer(_Harness harness) async {
  await harness.database.powersync.writeTransaction((tx) async {
    await tx.execute(
      '''
      INSERT INTO today_prayers(
        id, owner_id, local_date, prayer_id, personal_prayer_id,
        include_action, action_completed, created_at
      ) VALUES (?, ?, ?, NULL, NULL, 0, 0, ?)
      ''',
      [
        '0198a000-0000-7000-8000-00000000000a',
        'owner-1',
        '2026-10-06',
        '2026-10-06T05:30:00.000Z',
      ],
    );
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  expect(condition(), isTrue, reason: 'condition was never met');
}

class _RecordingClient extends http.BaseClient {
  final posts = <http.Request>[];
  final responses = <int>[];

  /// Answers 200 with every record refused, as the boundary does for a record
  /// it will not take.
  bool reject = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request && request.method == 'POST') {
      posts.add(request);
    }
    final status = responses.isEmpty ? 200 : responses.removeAt(0);
    final body = reject
        ? '{"accepted":0,"rejected":1,"code":"invalid_prayer"}'
        : '{"accepted":1,"rejected":0}';
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}
