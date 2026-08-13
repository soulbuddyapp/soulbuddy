import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships the licensed Source Serif display font locally', () async {
    final font = File('assets/fonts/SourceSerif4Display-Semibold.ttf');
    final license = File('assets/fonts/OFL-SourceSerif4.txt');

    expect(await font.exists(), isTrue);
    expect(await font.length(), greaterThan(0));
    expect(await license.exists(), isTrue);
    expect(
      await license.readAsString(),
      contains('SIL OPEN FONT LICENSE Version 1.1'),
    );
  });
}
