import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/feature_page.dart';
import '../data/bundled_scripture_source.dart';
import '../domain/scripture_passage.dart';

class ScripturePassageScreen extends StatefulWidget {
  const ScripturePassageScreen({
    required this.book,
    required this.chapter,
    super.key,
  });

  final String book;
  final int chapter;

  @override
  State<ScripturePassageScreen> createState() => _ScripturePassageScreenState();
}

class _ScripturePassageScreenState extends State<ScripturePassageScreen> {
  late Future<ScripturePassage> _passage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _passage = loadBundledChapter(book: widget.book, chapter: widget.chapter);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScripturePassage>(
      future: _passage,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return FeaturePage(
            title: '${widget.book} ${widget.chapter}',
            description: 'Opening Scripture…',
          );
        }
        if (snapshot.hasError) {
          return FeaturePage(
            title: '${widget.book} ${widget.chapter}',
            description: 'Scripture could not be opened just now.',
            action: OutlinedButton(
              onPressed: () => setState(_load),
              child: const Text('Try again'),
            ),
          );
        }

        final passage = snapshot.requireData;
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Remember'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      passage.reference,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'RSVCE · Scripture',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final verse in passage.verses)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: SelectableText.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${verse.number}  ',
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: verse.text),
                                  ],
                                ),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
