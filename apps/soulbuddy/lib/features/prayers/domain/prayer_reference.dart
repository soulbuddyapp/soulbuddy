enum PrayerSource { library, personal }

class PrayerReference {
  const PrayerReference.library(this.id) : source = PrayerSource.library;

  const PrayerReference.personal(this.id) : source = PrayerSource.personal;

  final PrayerSource source;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is PrayerReference && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);
}
