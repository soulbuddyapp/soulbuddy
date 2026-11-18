import '../domain/guide_profile.dart';

class GuideRepository {
  const GuideRepository({required this.read, required this.write});
  static const storageKey = 'soulbuddy.guide.name.v1';
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;

  Future<String?> load() => read(storageKey);
  Future<void> save(String name) {
    if (!GuideProfile.validName(name)) throw ArgumentError.value(name, 'name');
    return write(storageKey, name.trim());
  }
}
