import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../application/supporting_scripture_reference.dart';

class SupportingReadingChip extends StatelessWidget {
  const SupportingReadingChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final reference = SupportingScriptureReference.tryParse(label);
    if (reference == null) return Chip(label: Text(label));
    final parameters = <String, String>{
      if (reference.firstVerse != null)
        'firstVerse': reference.firstVerse.toString(),
      if (reference.lastVerse != null)
        'lastVerse': reference.lastVerse.toString(),
    };
    return ActionChip(
      key: Key(
        'formation-supporting-reading-${reference.book}-${reference.chapter}',
      ),
      avatar: const Icon(Icons.menu_book_outlined, size: 18),
      label: Text(reference.label),
      onPressed: () => context.push(
        Uri(
          path: '/remember/scripture/${reference.book}/${reference.chapter}',
          queryParameters: parameters,
        ).toString(),
      ),
    );
  }
}
