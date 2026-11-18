import 'package:characters/characters.dart';

abstract final class GuideProfile {
  static const names = ['Arel', 'Elio', 'Neri', 'Oria'];
  static bool validName(String name) {
    final length = name.trim().characters.length;
    return length > 0 && length <= 40;
  }
}
