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
  draft('draft'),
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
  telegram('telegram', 'Telegram', {'t.me', 'telegram.me'}),
  whatsappLink('whatsapp_link', 'WhatsApp', {'chat.whatsapp.com', 'wa.me'});

  const CircleProvider(this.wireValue, this.label, this.allowedHosts);

  final String wireValue;
  final String label;
  final Set<String> allowedHosts;

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

  bool allows(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    return uri.scheme.toLowerCase() == 'https' &&
        uri.userInfo.isEmpty &&
        allowedHosts.contains(host) &&
        (!uri.hasPort || uri.port == 443) &&
        uri.pathSegments.any((segment) => segment.trim().isNotEmpty);
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
    required this.directoryListed,
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
  final bool directoryListed;
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
    final provider = CircleProvider.fromWire(json['provider']);
    final memberCount = json['member_count'];
    return Circle(
      publicId: _requiredString(json, 'public_id'),
      name: _requiredString(json, 'name'),
      category: CircleCategory.fromWire(_requiredString(json, 'category')),
      description: _requiredString(json, 'description'),
      visibility: CircleVisibility.fromWire(
        _requiredString(json, 'visibility'),
      ),
      status: CircleStatus.fromWire(_requiredString(json, 'status')),
      directoryListed: _requiredBool(json, 'directory_listed'),
      provider: provider,
      openUri: _providerOpenUri(provider, json['open_url']),
      capabilities: List.unmodifiable(capabilities.cast<String>()),
      memberCount: memberCount == null
          ? null
          : memberCount is int
          ? memberCount
          : throw const FormatException('Circle member count must be an int.'),
      isOwner: _requiredBool(json, 'is_owner'),
      updatedAt: _optionalUtcDateTime(json['updated_at']),
    );
  }
}

Uri? _providerOpenUri(CircleProvider? provider, Object? value) {
  if (value == null) return null;
  if (provider == null || value is! String) {
    throw const FormatException('Circle provider URL is invalid.');
  }
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !provider.allows(uri)) {
    throw const FormatException('Circle provider URL is invalid.');
  }
  return uri;
}

DateTime? _optionalUtcDateTime(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Circle timestamp must be a string.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Circle timestamp is invalid.');
  }
  return parsed.toUtc();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Circle $key must be a boolean.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Circle $key is required.');
  }
  return value;
}
