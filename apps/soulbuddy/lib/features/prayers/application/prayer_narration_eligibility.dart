/// The narration boundary accepts only an immutable saved-prayer revision
/// this device already owns, and only when the server will speak it. The
/// request is refused above this many characters, so a control that could not
/// work is never offered.
const int prayerNarrationMaximumCharacters = 2000;

/// Whether narration can be obtained for one exact saved prayer revision.
///
/// This answers whether narration is obtainable, not whether a recording
/// happens to be cached on the device right now.
bool canObtainPrayerNarration({
  required String personalPrayerId,
  required String prayerRevisionId,
  required String prayerBody,
}) =>
    personalPrayerId.trim().isNotEmpty &&
    prayerRevisionId.trim().isNotEmpty &&
    prayerBody.trim().isNotEmpty &&
    prayerBody.runes.length <= prayerNarrationMaximumCharacters;
