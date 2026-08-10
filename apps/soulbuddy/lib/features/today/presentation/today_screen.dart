import 'package:flutter/material.dart';

import '../../../core/presentation/feature_page.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePage(
      title: 'Today',
      description: 'Pray. Act. Remember.',
    );
  }
}
