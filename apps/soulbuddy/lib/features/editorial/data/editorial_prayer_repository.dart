import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/prayer_language.dart';
import '../domain/editorial_item.dart';

class EditorialPrayer {
  const EditorialPrayer({required this.prayer, required this.editorial});

  final LibraryPrayer prayer;
  final EditorialItem editorial;
}

abstract interface class EditorialPrayerRepository {
  Stream<List<EditorialPrayer>> watchApproved({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
  });

  Stream<EditorialPrayer?> watchApprovedPrayer(String id);
}
