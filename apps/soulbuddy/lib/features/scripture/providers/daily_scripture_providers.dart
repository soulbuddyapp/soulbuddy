import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/daily_scripture_repository.dart';
import '../domain/daily_scripture.dart';

final dailyScriptureRepositoryProvider = Provider<DailyScriptureRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  final storage = ref.watch(secureStorageProvider);
  return DailyScriptureRepository(
    apiBaseUri: Uri.tryParse(AppConfig.apiBaseUrl),
    client: client,
    loadCatalog: () =>
        rootBundle.loadString('assets/content/daily_scriptures.json'),
    readCache: () => storage.read(key: 'scripture.daily.v1'),
    writeCache: (value) =>
        storage.write(key: 'scripture.daily.v1', value: value),
  );
});

final dailyScriptureProvider = FutureProvider<DailyScripture>((ref) {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  final observer = _ScriptureRefreshObserver(ref.invalidateSelf);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(observer);
  });
  return ref.watch(dailyScriptureRepositoryProvider).forDate(now);
});

class _ScriptureRefreshObserver extends WidgetsBindingObserver {
  _ScriptureRefreshObserver(this.refresh);
  final VoidCallback refresh;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}
