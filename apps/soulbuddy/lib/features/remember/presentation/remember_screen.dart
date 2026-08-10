import 'package:flutter/material.dart';

import '../../../core/presentation/feature_page.dart';

class RememberScreen extends StatelessWidget {
  const RememberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePage(
      title: 'What you have recorded',
      description: 'Encounters, Scripture, people, family, and lessons.',
    );
  }
}
