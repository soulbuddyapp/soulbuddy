import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/prayer_narration_fallback_policy.dart';

void main() {
  const policy = PrayerNarrationFallbackPolicy();

  test('uses the private device voice while a natural voice is not cached', () {
    expect(
      policy.decide(hasCachedNarration: false),
      PrayerNarrationFallbackDecision.deviceVoice,
    );
  });

  test('keeps the natural voice when the exact revision is cached', () {
    expect(
      policy.decide(hasCachedNarration: true),
      PrayerNarrationFallbackDecision.cachedNarration,
    );
  });
}
