import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disables Android backup for encrypted secure storage', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(manifest, contains('android:allowBackup="false"'));
  });
}
