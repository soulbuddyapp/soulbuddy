import '../domain/circle.dart';
import '../domain/circle_message.dart';

abstract interface class CircleRepository {
  Stream<List<Circle>> watchCircles();

  Stream<Circle?> watchCircle(String circleId);

  Stream<List<CircleMessage>> watchMessages(String circleId);

  Future<String> createCircle(String name);

  Future<void> sendMessage(String circleId, String body);
}
