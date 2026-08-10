import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import 'sync_issue.dart';

class LaravelSyncUnavailable implements Exception {
  const LaravelSyncUnavailable([this.statusCode]);

  final int? statusCode;

  @override
  String toString() => 'SoulBuddy sync is temporarily unavailable.';
}

class LaravelBackendConnector extends PowerSyncBackendConnector {
  LaravelBackendConnector({
    required this.apiBaseUri,
    required this.powerSyncEndpoint,
    required this.accessToken,
    required this.client,
    Uuid uuid = const Uuid(),
  }) : _uuid = uuid;

  final Uri apiBaseUri;
  final String powerSyncEndpoint;
  final Future<String?> Function() accessToken;
  final http.Client client;
  final Uuid _uuid;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    if (powerSyncEndpoint.isEmpty) {
      return null;
    }

    final sessionToken = await accessToken();
    if (sessionToken == null || sessionToken.isEmpty) {
      return null;
    }

    final response = await client.get(
      _apiUri('/api/sync/token'),
      headers: {'authorization': 'Bearer $sessionToken'},
    );
    if (response.statusCode == 401) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LaravelSyncUnavailable(response.statusCode);
    }

    final payload = _decodeObject(response.body);
    final token = payload['token'];
    final userId = payload['user_id'];
    if (token is! String || token.isEmpty || userId is! String) {
      throw const LaravelSyncUnavailable();
    }

    return PowerSyncCredentials(
      endpoint: powerSyncEndpoint,
      token: token,
      userId: userId,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    await uploadTransaction(
      transaction,
      recordIssue: (issue) => database.execute(
        '''
        INSERT INTO sync_issues(
          id, record_type, record_id, code, message, created_at, resolved_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          _uuid.v7(),
          issue.recordType,
          issue.recordId,
          issue.code,
          issue.message,
          issue.createdAt.toUtc().toIso8601String(),
        ],
      ),
    );
  }

  Future<void> uploadTransaction(
    CrudTransaction transaction, {
    Future<void> Function(SyncIssue issue)? recordIssue,
  }) async {
    final sessionToken = await accessToken();
    if (sessionToken == null || sessionToken.isEmpty) {
      throw const LaravelSyncUnavailable(401);
    }

    final operations = transaction.crud.map((entry) {
      final operationKey = [
        transaction.transactionId,
        entry.clientId,
        entry.table,
        entry.id,
        entry.op.toJson(),
      ].join(':');
      return {
        'operation_id': _uuid.v5(
          Namespace.url.value,
          'soulbuddy:$operationKey',
        ),
        'table': entry.table,
        'type': entry.op.toJson().toLowerCase(),
        'id': entry.id,
        'data': entry.opData ?? <String, dynamic>{},
      };
    }).toList(growable: false);

    final response = await client.post(
      _apiUri('/api/sync/mutations'),
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({'operations': operations}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LaravelSyncUnavailable(response.statusCode);
    }

    final payload = _decodeObject(response.body);
    final rejected = payload['rejected'];
    if (rejected is num && rejected > 0 && recordIssue != null) {
      final responseCode = payload['code'];
      await recordIssue(
        SyncIssue(
          recordType: transaction.crud.firstOrNull?.table ?? 'sync_batch',
          recordId: transaction.crud.firstOrNull?.id ??
              'transaction-${transaction.transactionId}',
          code: responseCode is String ? responseCode : 'rejected',
          message: 'A saved item needs attention before it can sync.',
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }

    await transaction.complete();
  }

  Uri _apiUri(String path) {
    final normalized = apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$normalized$path');
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // The caller reports a generic availability failure without private data.
    }
    throw const LaravelSyncUnavailable();
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
