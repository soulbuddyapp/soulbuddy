import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/scripture/data/daily_scripture_repository.dart';
import 'package:soulbuddy/features/scripture/domain/daily_scripture.dart';

void main() {
  final catalogText = File(
    'assets/content/daily_scriptures.json',
  ).readAsStringSync();
  final catalog = (jsonDecode(catalogText) as List)
      .cast<Map<String, dynamic>>();
  final day = DateTime(2026, 9, 11);
  Map<String, dynamic> remote() => {
    ...catalog.first,
    'date': '2026-09-11',
    'theme': 'A new beginning',
  };

  test('API and app bundle the same complete 28-day rotation', () {
    expect(catalog.length, 28);
    expect(
      File(
        '../../services/api/resources/scripture/daily_scriptures.json',
      ).readAsStringSync(),
      catalogText,
    );
    for (final entry in catalog) {
      expect(
        DailyScripture.fromJson({...entry, 'date': '2026-09-11'}).text,
        isNotEmpty,
      );
    }
  });

  test('a dated API replacement wins and is cached', () async {
    String? stored;
    final repo = DailyScriptureRepository(
      apiBaseUri: Uri.parse('https://sbuddy.example'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/scriptures/daily');
        expect(request.url.queryParameters['date'], '2026-09-11');
        return http.Response(jsonEncode({'data': remote()}), 200);
      }),
      loadCatalog: () async => catalogText,
      readCache: () async => stored,
      writeCache: (value) async => stored = value,
    );
    expect((await repo.forDate(day)).theme, 'A new beginning');
    expect(stored, contains('A new beginning'));
  });

  test(
    'offline cache is date-specific and fallback changes at midnight',
    () async {
      final repo = DailyScriptureRepository(
        apiBaseUri: Uri.parse('https://sbuddy.example'),
        client: MockClient((_) async => http.Response('unavailable', 503)),
        loadCatalog: () async => catalogText,
        readCache: () async => jsonEncode({'2026-09-11': remote()}),
        writeCache: (_) async {},
      );
      expect((await repo.forDate(day)).theme, 'A new beginning');
      final next = await repo.forDate(DateTime(2026, 9, 12));
      expect(next.date, '2026-09-12');
      expect(next.theme, isNot('A new beginning'));
      expect(
        next.reference,
        isNot((await repo.forDate(DateTime(2026, 9, 13))).reference),
      );
    },
  );

  test(
    'wrong-date, malformed API and corrupted cache fall back safely',
    () async {
      for (final response in [
        jsonEncode({
          'data': {...remote(), 'date': '2026-09-10'},
        }),
        '{}',
        'bad json',
      ]) {
        final repo = DailyScriptureRepository(
          apiBaseUri: Uri.parse('https://sbuddy.example'),
          client: MockClient((_) async => http.Response(response, 200)),
          loadCatalog: () async => catalogText,
          readCache: () async => 'corrupted',
          writeCache: (_) async {},
        );
        expect((await repo.forDate(day)).date, '2026-09-11');
        expect((await repo.forDate(day)).theme, isNot('A new beginning'));
      }
    },
  );

  test('cache failures do not discard a valid remote replacement', () async {
    final repo = DailyScriptureRepository(
      apiBaseUri: Uri.parse('https://sbuddy.example'),
      client: MockClient(
        (_) async => http.Response(jsonEncode({'data': remote()}), 200),
      ),
      loadCatalog: () async => catalogText,
      readCache: () async => throw StateError('locked'),
      writeCache: (_) async => throw StateError('full'),
    );
    expect((await repo.forDate(day)).theme, 'A new beginning');
  });
}
