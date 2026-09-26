import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Python decodes and verifies every committed media asset',
    () async {
      final result = await Process.run(
        Platform.isWindows ? 'python' : 'python3',
        ['scripts/commitments/verify_assets.py'],
        workingDirectory: '../..',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report =
          jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(report['ok'], true);
      expect(report['errors'], isEmpty);
      expect(report['assets'], hasLength(8));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
