import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_catalog.dart';
import 'package:soulbuddy/features/daily_formation/presentation/teaching_reflection_sheet.dart';

const day = FormationDay(
  id: 'D001',
  day: 1,
  packId: 'P01',
  focus: 'Image of God',
  objective: '',
  scripture: '',
  reflection: 'Old reflection',
  action: 'Old action',
  videoIds: [],
);
void main() {
  testWidgets('retains answers on failed save and completes after retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TeachingReflectionSheet(
              day: day,
              videoId: 'V1',
              guideName: 'Arel',
              onSave: (completion) async {
                attempts++;
                expect(completion.reflection, 'A friend listened');
                if (attempts == 1) throw StateError('disk');
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('When did you last feel truly seen?'), findsOneWidget);
    expect(find.text('Private reflection'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'A friend listened');
    await tester.ensureVisible(find.text('Complete today'));
    await tester.tap(find.text('Complete today'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Try again.'), findsOneWidget);
    expect(find.text('A friend listened'), findsOneWidget);
    await tester.tap(find.text('Complete today'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
  testWidgets('back cannot dismiss a save in progress', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  isDismissible: false,
                  enableDrag: false,
                  builder: (_) => TeachingReflectionSheet(
                    day: day,
                    videoId: 'V1',
                    guideName: 'Arel',
                    onSave: (_) => pending.future,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Complete today'));
    await tester.tap(find.text('Complete today'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Private reflection'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Private reflection'), findsNothing);
  });
}
