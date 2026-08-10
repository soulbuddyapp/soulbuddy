import 'package:flutter/material.dart';

import '../../../core/presentation/feature_page.dart';

class PrayersScreen extends StatelessWidget {
  const PrayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePage(
      title: 'Prayers',
      description: 'Choose from the library or shape a prayer for today.',
    );
  }
}
