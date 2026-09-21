import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/goal.dart';
import '../providers/goal_providers.dart';

Future<void> createMeditationGoal(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  try {
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Name an important Goal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Goal',
            hintText: 'For example: Serve my family with patience',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(dialogContext, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) Navigator.pop(dialogContext, title);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (title == null || !context.mounted) return;
    try {
      final repository = await ref.read(goalRepositoryProvider.future);
      final goal = await repository.create(title: title, mode: GoalMode.mixed);
      if (context.mounted) context.go('/goals/${goal.id}/meditate');
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal could not be saved. Try again.')),
        );
      }
    }
  } finally {
    controller.dispose();
  }
}
