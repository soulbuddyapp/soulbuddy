import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('release Android manifest grants internet access', () {
    final manifest = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    final permission = manifest
        .findAllElements('uses-permission')
        .where(
          (element) =>
              element.getAttribute(
                'name',
                namespace: 'http://schemas.android.com/apk/res/android',
              ) ==
              'android.permission.INTERNET',
        )
        .singleOrNull;

    expect(permission, isNotNull);
    expect(
      permission?.getAttribute(
        'node',
        namespace: 'http://schemas.android.com/tools',
      ),
      isNot('remove'),
      reason: 'The production APK must reach the SoulBuddy API.',
    );
  });
}
