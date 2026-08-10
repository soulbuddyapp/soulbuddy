import 'package:flutter/material.dart';

import '../../../core/presentation/feature_page.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePage(
      title: 'Record',
      description: 'Write what happened before it fades.',
      action: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Record an encounter'),
      ),
    );
  }
}
