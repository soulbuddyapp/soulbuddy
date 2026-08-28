import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/config/app_config.dart';

void main() {
  test('prayer generation is disabled unless explicitly enabled at build time', () {
    expect(AppConfig.prayerGenerationEnabled, isFalse);
  });
}
