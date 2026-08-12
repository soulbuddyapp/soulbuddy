enum CircleMessageDelivery { onThisDevice }

class CircleMessage {
  const CircleMessage({
    required this.id,
    required this.circleId,
    required this.body,
    required this.createdAt,
    required this.isMine,
    required this.delivery,
  });

  final String id;
  final String circleId;
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final CircleMessageDelivery delivery;
}
