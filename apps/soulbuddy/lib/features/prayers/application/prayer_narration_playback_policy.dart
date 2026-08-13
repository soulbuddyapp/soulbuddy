enum PrayerAudioRoute { speaker, headphones, silent, doNotDisturb, unknown }

enum PrayerNarrationPlaybackDecision { autoplay, manual }

class PrayerNarrationPlaybackPolicy {
  const PrayerNarrationPlaybackPolicy();

  PrayerNarrationPlaybackDecision decide({
    required bool explicitInAppOpen,
    required bool autoplayEnabled,
    required bool narrationReady,
    required PrayerAudioRoute audioRoute,
    required bool interruptionsAllowed,
    required bool alreadyAttempted,
  }) {
    final safeRoute =
        audioRoute == PrayerAudioRoute.speaker ||
        audioRoute == PrayerAudioRoute.headphones;
    return explicitInAppOpen &&
            autoplayEnabled &&
            narrationReady &&
            safeRoute &&
            interruptionsAllowed &&
            !alreadyAttempted
        ? PrayerNarrationPlaybackDecision.autoplay
        : PrayerNarrationPlaybackDecision.manual;
  }
}
