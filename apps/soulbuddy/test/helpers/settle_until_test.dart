import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'settle_until.dart';

void main() {
  testWidgets('a stage still settles when its work needs more than a hundred '
      'steps', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _SlowJourneyScreen()));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(
      find.text('Saving…'),
      findsOneWidget,
      reason: 'The stage is still busy while its writes are outstanding.',
    );
    await settleUntil(tester, () => find.text('Settled').evaluate().isNotEmpty);
    expect(find.text('Settled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A journey stand-in whose writes take two hundred and fifty steps.
///
/// The real journey leaves a stage behind by writing to a database, and how
/// many steps those writes take is a property of the machine, not of the app.
/// A settle loop with a fixed ceiling — of seconds, of sleeps, or of frames —
/// reports that machine as a journey that never advanced, which is how the
/// commitment journey test came to fail on some full-suite runs and not others.
class _SlowJourneyScreen extends StatefulWidget {
  const _SlowJourneyScreen();
  @override
  State<_SlowJourneyScreen> createState() => _SlowJourneyScreenState();
}

class _SlowJourneyScreenState extends State<_SlowJourneyScreen> {
  static const _steps = 250;
  int _remaining = _steps;
  bool _busy = false, _settled = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _settled
          ? const Text('Settled')
          : FilledButton(
              onPressed: _busy ? null : _advance,
              child: Text(_busy ? 'Saving…' : 'Continue'),
            ),
    ),
  );
  void _advance() {
    setState(() {
      _busy = true;
      _remaining = _steps;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _step());
  }

  void _step() {
    if (!mounted) return;
    if (_remaining > 0) {
      setState(() => _remaining--);
      WidgetsBinding.instance.addPostFrameCallback((_) => _step());
      return;
    }
    setState(() {
      _busy = false;
      _settled = true;
    });
  }
}
