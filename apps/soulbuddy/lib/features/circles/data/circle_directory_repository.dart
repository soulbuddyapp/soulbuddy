import '../domain/circle.dart';

class CircleDiscoveryQuery {
  const CircleDiscoveryQuery({
    this.category,
    this.search,
    this.cursor,
    this.limit = 20,
  });

  final CircleCategory? category;
  final String? search;
  final String? cursor;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is CircleDiscoveryQuery &&
      other.category == category &&
      other.search == search &&
      other.cursor == cursor &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(category, search, cursor, limit);
}

class CirclePage {
  const CirclePage({required this.items, this.nextCursor});

  final List<Circle> items;
  final String? nextCursor;
}

class CircleDraft {
  const CircleDraft({
    required this.name,
    required this.category,
    required this.description,
    required this.visibility,
    required this.provider,
    required this.openUri,
  });

  final String name;
  final CircleCategory category;
  final String description;
  final CircleVisibility visibility;
  final CircleProvider provider;
  final Uri openUri;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'category': category.wireValue,
    'description': description.trim(),
    'visibility': visibility.wireValue,
    'provider': provider.wireValue,
    'open_url': openUri.toString(),
  };
}

class CircleUpdate {
  const CircleUpdate({
    this.name,
    this.category,
    this.description,
    this.visibility,
    this.status,
    this.provider,
    this.openUri,
  });

  final String? name;
  final CircleCategory? category;
  final String? description;
  final CircleVisibility? visibility;
  final CircleStatus? status;
  final CircleProvider? provider;
  final Uri? openUri;

  Map<String, dynamic> toJson() => {
    if (name case final value?) 'name': value.trim(),
    if (category case final value?) 'category': value.wireValue,
    if (description case final value?) 'description': value.trim(),
    if (visibility case final value?) 'visibility': value.wireValue,
    if (status case final value?) 'status': value.wireValue,
    if (provider case final value?) 'provider': value.wireValue,
    if (openUri case final value?) 'open_url': value.toString(),
  };
}

abstract interface class CircleDirectoryRepository {
  Future<CirclePage> discover(CircleDiscoveryQuery query);

  Future<List<Circle>> listOwned();

  Future<Circle?> get(String publicId);

  Future<Circle> create(CircleDraft draft);

  Future<Circle> update(String publicId, CircleUpdate update);

  Future<void> report(String publicId, String reason);
}
