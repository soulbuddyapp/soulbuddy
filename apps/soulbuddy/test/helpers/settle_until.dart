import 'package:flutter_test/flutter_test.dart';

/// Waits for [done] by pumping frames and yielding to the real event loop.
///
/// A journey leaves a stage behind by writing to the database, and those writes
/// only make progress outside the fake clock — for as long as the machine they
/// run on takes. Waiting on a clock, however generous, therefore reports a slow
/// or loaded machine as a journey that never advanced, which is how the
/// commitment journey test came to fail on some full-suite runs and not others.
/// This waits for the work instead: every pass through the loop is one turn of
/// the real event loop the writes need and one frame the screen asked for, for
/// as many passes as that work turns out to take.
///
/// There is deliberately no ceiling here. Any ceiling is a guess about how long
/// the work may take, and a guess that is wrong fails a journey that was on its
/// way; a screen that truly never settles instead runs into the test package's
/// own timeout, which is a louder and more honest report than a passing test.
Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
  while (!done()) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
  }
}
