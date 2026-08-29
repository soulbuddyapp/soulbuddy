class LegacyCircleSummary {
  const LegacyCircleSummary({
    required this.id,
    required this.name,
    required this.messageCount,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int messageCount;
  final DateTime updatedAt;
}

class LegacyCircleMessage {
  const LegacyCircleMessage({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String body;
  final DateTime createdAt;
}

class LegacyCircleArchive {
  const LegacyCircleArchive({required this.summary, required this.messages});

  final LegacyCircleSummary summary;
  final List<LegacyCircleMessage> messages;
}
