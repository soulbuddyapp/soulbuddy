import '../domain/affirmation_prayer.dart';
import '../domain/prayer_release.dart';

/// Local access to a published weekly prayer release.
///
/// Adding is explicit and idempotent, and the exact wording is stored locally
/// so an added collection works offline before the canonical catalog arrives.
abstract interface class PrayerReleaseRepository {
  /// Every published release this device has discovered, newest first. An added
  /// release is listed even after it stops appearing in discovery.
  Stream<List<PrayerRelease>> watchReleases();

  /// The releases this account has added, newest first.
  Stream<List<PrayerRelease>> watchAddedReleases();

  /// One release by slug, or null when it has never been discovered.
  Stream<PrayerRelease?> watchRelease(String slug);

  /// The exact wording of an added release's items, in source order.
  Stream<List<PrayerReleaseItemContent>> watchReleaseContent(String slug);

  /// The added item content for one canonical prayer, or null when that prayer
  /// is not part of an added collection.
  Stream<PrayerReleaseItemContent?> watchContentForPrayer(String libraryPrayerId);

  /// Refreshes discovery metadata and the preference from the account's server.
  Future<void> refresh();

  /// Refreshes discovery metadata and the preference again, on a failure.
  Future<void> retry();

  /// Adds a collection. Adding an already-added collection is the same outcome,
  /// and a failure leaves nothing behind.
  Future<PrayerReleaseItemContent> addRelease(String slug);

  Stream<PrayerReleasePreference> watchPreference();

  /// Stores the weekly delivery preference for this account.
  Future<void> savePreference(PrayerReleasePreference preference);

  /// Saves one terminal counted prayer session. It is written once.
  Future<void> saveAffirmationSession(AffirmationPrayerSession session);
}
