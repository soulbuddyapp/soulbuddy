class DailyScripture {
  DailyScripture._(this._data);

  final Map<String, dynamic> _data;
  String get date => _data['date'] as String;
  String get book => _data['book'] as String;
  int get chapter => _data['chapter'] as int;
  String get reference => _data['reference'] as String;
  String get text => _data['text'] as String;
  String get translation => _data['translation'] as String;
  String get theme => _data['theme'] as String;
  String get reflection => _data['reflection'] as String;
  String get prayer => _data['prayer'] as String;
  String get practice => _data['practice'] as String;
  String get precept => _data['precept'] as String;

  factory DailyScripture.fromJson(Map<String, dynamic> data) {
    for (final key in [
      'date',
      'book',
      'chapter',
      'reference',
      'text',
      'translation',
      'theme',
      'reflection',
      'prayer',
      'practice',
      'precept',
    ]) {
      if (key == 'chapter') continue;
      if (data[key] is! String ||
          (data[key] as String).trim().isEmpty ||
          (data[key] as String).length > 12000) {
        throw FormatException('Invalid daily scripture $key');
      }
    }
    if (data['chapter'] is! int || (data['chapter'] as int) < 1) {
      throw const FormatException('Invalid daily scripture chapter');
    }
    final date = data['date'] as String;
    final parsed = DateTime.tryParse(date);
    if (parsed == null || scriptureDateKey(parsed) != date) {
      throw const FormatException('Invalid scripture date');
    }
    if (!['guard-the-gate', 'strength-for-today'].contains(data['precept'])) {
      throw const FormatException('Invalid practice');
    }
    return DailyScripture._(Map.unmodifiable(data));
  }

  Map<String, dynamic> toJson() => Map.of(_data);
}

String scriptureDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
