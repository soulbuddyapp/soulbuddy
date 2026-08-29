import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supported Circles contain no local chat composer or send-message API', () {
    final presentation = Directory('lib/features/circles/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final directoryContract = File(
      'lib/features/circles/data/circle_directory_repository.dart',
    ).readAsStringSync();

    for (final marker in const [
      'circle-message-field',
      'send-circle-message',
      'sendMessage(',
      'watchMessages(',
      '_MessageComposer',
      'Begin the conversation',
    ]) {
      expect(presentation, isNot(contains(marker)));
      expect(directoryContract, isNot(contains(marker)));
    }
  });

  test('legacy Circle tables remain local-only migration data', () {
    final schema = File('lib/core/database/app_schema.dart').readAsStringSync();
    for (final table in const ['circles', 'circle_members', 'circle_messages']) {
      expect(
        RegExp("Table\\.localOnly\\(\\s*'$table'").hasMatch(schema),
        isTrue,
        reason: '$table must never enter the PowerSync upload queue.',
      );
    }
  });

  test('Circle boundaries contain no direct logging or analytics sink', () {
    final source = Directory('lib/features/circles')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final marker in const [
      'print(',
      'debugPrint(',
      'developer.log(',
      'FirebaseAnalytics',
      'logEvent(',
      'analytics.log',
    ]) {
      expect(
        source,
        isNot(contains(marker)),
        reason: 'Circle metadata or legacy messages must not enter $marker',
      );
    }
  });
}
