import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/circles/domain/circle.dart';

void main() {
  test('Circle providers accept group links only', () {
    expect(
      CircleProvider.telegram.allows(Uri.parse('https://t.me/+group')),
      isTrue,
    );
    expect(
      CircleProvider.whatsappLink.allows(
        Uri.parse('https://chat.whatsapp.com/group'),
      ),
      isTrue,
    );
    expect(
      CircleProvider.whatsappLink.allows(
        Uri.parse('https://wa.me/2348012345678'),
      ),
      isFalse,
    );
    expect(
      CircleProvider.telegram.allows(
        Uri.parse('https://chat.whatsapp.com/group'),
      ),
      isFalse,
    );
  });
}
