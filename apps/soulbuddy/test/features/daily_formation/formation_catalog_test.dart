import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the reviewed offline formation catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/content/daily_formation_v1.json',
    );
    final catalog = FormationCatalog.fromJson(jsonDecode(raw) as Map);

    expect(catalog.version, 1);
    expect(catalog.videos, hasLength(45));
    expect(catalog.packs, hasLength(10));
    expect(catalog.days, hasLength(70));
    expect(catalog.videosById['V045']?.runtimeSeconds, 623);
    expect(catalog.days[56].videoIds, contains('V045'));
  });
}
