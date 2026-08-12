enum AppFeedbackIntent {
  selection,
  saved,
  prayerCompleted,
  warning,
  dismissed,
  publicationEligible,
}

enum AppHaptic { selection, light, medium, warning, heavy }

enum AppFeedbackSound { softTap, gentleCompletion, publicationEligible }

enum AppFeedbackVisualCue {
  none,
  check,
  completion,
  warning,
  dismissed,
  lightMotes,
}

class AppFeedbackResult {
  const AppFeedbackResult({required this.visualCue, required this.animate});

  final AppFeedbackVisualCue visualCue;
  final bool animate;
}
