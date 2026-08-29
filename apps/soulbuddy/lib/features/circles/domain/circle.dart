enum CircleCategory {
  accountability('accountability', 'Accountability'),
  dailyExhortation('daily_exhortation', 'Daily Exhortation'),
  bibleStudy('bible_study', 'Bible Study');

  const CircleCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CircleCategory fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown Circle category: $value'),
  );
}

enum CircleVisibility {
  public('public', 'Public'),
  unlisted('unlisted', 'Unlisted'),
  private('private', 'Private');

  const CircleVisibility(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CircleVisibility fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown Circle visibility: $value'),
  );
}

enum CircleStatus {
  active('active'),
  paused('paused'),
  suspended('suspended'),
  archived('archived');

  const CircleStatus(this.wireValue);

  final String wireValue;

  static CircleStatus fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown Circle status: $value'),
  );
}

enum CircleProvider {
  telegram('telegram', 'Telegram'),
  whatsappLink('whatsapp_link', 'WhatsApp');

  const CircleProvider(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CircleProvider? fromWire(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Circle provider must be a string.');
    }
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => throw FormatException('Unknown Circle provider: $value'),
    );
  }
}

class Circle {
  const Circle({
    required this.publicId,
    required this.name,
    required this.category,
    required this.description,
    required this.visibility,
    required this.status,
    required this.capabilities,
    required this.isOwner,
    this.provider,
    this.openUri,
    this.memberCount,
    this.updatedAt,
  });

  final String publicId;
  final String name;
  final CircleCategory category;
  final String description;
  final CircleVisibility visibility;
  final CircleStatus status;
  final CircleProvider? provider;
  final Uri? openUri;
  final List<String> capabilities;
  final int? memberCount;
  final bool isOwner;
  final DateTime? updatedAt;

  bool get canOpen =>
      openUri != null && capabilities.contains('open_link');

  factory Circle.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    if (capabilities is! List<dynamic> ||
        capabilities.any((item) => item is! String)) {
      throw const FormatException('Circle capabilities must be strings.');
    }
    final openUrl = json['open_url'];
    final memberCount = json['member_count'];
    final updatedAt = json['updated_at'];
    return Circle(
      publicId: _requiredString(json, 'public_id'),
      name: _requiredString(json, 'name'),
      category: CircleCategory.fromWire(_requiredString(json, 'category')),
      description: _requiredString(json, 'description'),
      visibility: CircleVisibility.fromWire(
        _requiredString(json, 'visibility'),
      ),
      status: CircleStatus.fromWire(_requiredString(json, 'status')),
      provider: CircleProvider.fromWire(json['provider']),
      openUri: openUrl == null
          ? null
          : Uri.tryParse(openUrl is String ? openUrl : '')
                ?.takeIf((uri) => uri.hasScheme),
      capabilities: List.unmodifiable(capabilities.cast<String>()),
      memberCount: memberCount == null
          ? null
          : memberCount is int
          ? memberCount
          : throw const FormatException('Circle member count must be an int.'),
      isOwner: json['is_owner'] == true,
      updatedAt: updatedAt == null
          ? null
          : DateTime.parse(updatedAt as String).toUtc(),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Circle $key is required.');
  }
  return value;
}

extension<T> on T {
  T? takeIf(bool Function(T value) predicate) => predicate(this) ? this : null;
}
