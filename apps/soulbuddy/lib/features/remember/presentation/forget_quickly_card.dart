import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class ForgetQuicklyCard extends StatelessWidget {
  const ForgetQuicklyCard({super.key, required this.expanded});

  final bool expanded;

  static const detail =
      'Miracles happen around us daily. It is God’s little way of showing '
      'that He loves and cares for us, but we often forget and take them for '
      'granted. Think about the last time you said “Wow,” “Thank God,” or “I '
      'am so grateful, Lord.” Do you remember what He did? Make it a habit to '
      'remember.';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (expanded) {
      return Card(
        key: const Key('forget-quickly-expanded'),
        color: colors.surfaceContainerLow,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bookmark_added_outlined),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('We forget quickly')),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(detail),
            ],
          ),
        ),
      );
    }
    return Card(
      key: const Key('forget-quickly-collapsed'),
      color: colors.surfaceContainerLow,
      child: const ExpansionTile(
        leading: Icon(Icons.bookmark_added_outlined),
        title: Text('We forget quickly'),
        subtitle: Text(
          'Miracles happen around us daily, but we often forget…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text(detail),
          ),
        ],
      ),
    );
  }
}
