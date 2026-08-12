import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ships one compact signature illustration', () async {
    final data = await rootBundle.load(
      'assets/images/soulbuddy_olive_memorial.webp',
    );

    expect(data.lengthInBytes, greaterThan(20 * 1024));
    expect(data.lengthInBytes, lessThan(500 * 1024));
  });
}
