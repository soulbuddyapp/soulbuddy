import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/daily_scripture.dart';

class DailyScriptureRepository {
  DailyScriptureRepository({
    required this.apiBaseUri,
    required this.client,
    required this.loadCatalog,
    required this.readCache,
    required this.writeCache,
  });

  final Uri? apiBaseUri;
  final http.Client client;
  final Future<String> Function() loadCatalog;
  final Future<String?> Function() readCache;
  final Future<void> Function(String value) writeCache;
  Future<void> _pendingWrite = Future.value();

  Future<DailyScripture> forDate(DateTime localDate) async {
    final date = scriptureDateKey(localDate);
    final base = apiBaseUri;
    if (base != null && base.hasScheme) {
      try {
        final uri = Uri.parse(
          '${base.toString().replaceFirst(RegExp(r'/$'), '')}/api/scriptures/daily',
        ).replace(queryParameters: {'date': date});
        final response = await client
            .get(uri, headers: {'accept': 'application/json'})
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200 && response.body.length <= 65536) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final scripture = DailyScripture.fromJson(
            decoded['data'] as Map<String, dynamic>,
          );
          if (scripture.date == date) {
            try {
              await _cache(scripture);
            } catch (_) {
              /* Reading remains available if storage is full. */
            }
            return scripture;
          }
        }
      } catch (_) {
        /* Offline and old servers use the dated fallback below. */
      }
    }
    final cache = await _readCache();
    try {
      final saved = DailyScripture.fromJson(
        cache[date] as Map<String, dynamic>,
      );
      if (saved.date == date) return saved;
    } catch (_) {
      /* A corrupt entry must not prevent an offline reading. */
    }
    final catalog = jsonDecode(await loadCatalog()) as List;
    final day =
        DateTime.utc(
          localDate.year,
          localDate.month,
          localDate.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final selection = catalog[day % catalog.length] as Map<String, dynamic>;
    return DailyScripture.fromJson({...selection, 'date': date});
  }

  Future<Map<String, dynamic>> _readCache() async {
    try {
      final raw = await readCache();
      if (raw != null) return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      /* Cache is optional. */
    }
    return {};
  }

  Future<void> _cache(DailyScripture scripture) {
    final saving = _pendingWrite.then((_) async {
      final cache = await _readCache();
      cache[scripture.date] = scripture.toJson();
      final dates = cache.keys.toList()..sort();
      for (final date in dates.take(
        (dates.length - 7).clamp(0, dates.length),
      )) {
        cache.remove(date);
      }
      await writeCache(jsonEncode(cache));
    });
    _pendingWrite = saving.catchError((Object _) {});
    return saving;
  }
}
