import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';
import 'package:soulbuddy/features/scripture/domain/scripture_passage.dart';
import 'package:soulbuddy/features/scripture/presentation/scripture_picker_sheet.dart';
import 'package:soulbuddy/features/scripture/providers/scripture_providers.dart';

void main() {
  testWidgets('picker returns Scripture and fits a small phone at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ScriptureSelection? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scriptureRepositoryProvider.overrideWithValue(
            const _FakeScriptureRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const Key('open-scripture-picker'),
                  onPressed: () async {
                    selected = await showScripturePicker(context);
                  },
                  child: const Text('Choose Scripture'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-scripture-picker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scripture-picker-book')), findsOneWidget);
    expect(find.byKey(const Key('scripture-picker-chapter')), findsOneWidget);
    expect(
      find.byKey(const Key('scripture-picker-first-verse')),
      findsOneWidget,
    );
    expect(find.text('1  Ask God for wisdom.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('scripture-picker-choose')));
    await tester.tap(find.byKey(const Key('scripture-picker-choose')));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.translation, 'RSVCE');
    expect(selected!.reference, 'James 1:1');
    expect(selected!.passage.verses.single.text, 'Ask God for wisdom.');
    expect(tester.takeException(), isNull);
  });
}

class _FakeScriptureRepository implements ScriptureRepository {
  const _FakeScriptureRepository();

  @override
  Future<List<String>> books() async => const ['James'];

  @override
  Future<List<int>> chapters(String book) async => const [1];

  @override
  Future<ScripturePassage> chapter({
    required String book,
    required int chapter,
  }) async => ScripturePassage(
    reference: '$book $chapter',
    verses: const [
      ScriptureVerse(number: 1, text: 'Ask God for wisdom.'),
      ScriptureVerse(number: 2, text: 'Ask in faith.'),
    ],
  );

  @override
  Future<ScripturePassage> verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) async {
    final source = await this.chapter(book: book, chapter: chapter);
    return ScripturePassage(
      reference: '$book $chapter:$firstVerse',
      verses: source.verses
          .where(
            (verse) =>
                verse.number >= firstVerse && verse.number <= lastVerse,
          )
          .toList(growable: false),
    );
  }
}
