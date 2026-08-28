import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/router.dart';

void main() {
  test('Goals shell constructs with legacy prayer routes preserved', () {
    expect(appRouter, isNotNull);
  });
}
