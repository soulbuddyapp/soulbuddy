class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}
