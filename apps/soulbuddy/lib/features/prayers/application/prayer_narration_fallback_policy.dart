/// Selects the local voice only while the exact private narration is absent.
///
/// A remote cache is an enhancement. Prayer must still begin when a network
/// request, upload, or speech provider is temporarily unavailable.
enum PrayerNarrationFallbackDecision { cachedNarration, deviceVoice }

class PrayerNarrationFallbackPolicy {
  const PrayerNarrationFallbackPolicy();

  PrayerNarrationFallbackDecision decide({required bool hasCachedNarration}) =>
      hasCachedNarration
      ? PrayerNarrationFallbackDecision.cachedNarration
      : PrayerNarrationFallbackDecision.deviceVoice;
}
