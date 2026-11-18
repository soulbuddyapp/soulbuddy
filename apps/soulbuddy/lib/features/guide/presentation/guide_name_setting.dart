import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/guide_profile.dart';
import '../providers/guide_providers.dart';
import 'guide_intro_sheet.dart';

class GuideNameSetting extends ConsumerWidget {
  const GuideNameSetting({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(guideNameProvider);
    return name.when(
      loading: () => const ListTile(title: Text('Guide name')),
      error: (_, _) => ListTile(
        title: const Text('Guide name unavailable'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(guideNameProvider),
          child: const Text('Try again'),
        ),
      ),
      data: (value) => ListTile(
        leading: const Icon(Icons.auto_awesome_outlined),
        title: const Text('Guide name'),
        subtitle: value == null ? null : Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final initial =
              value ??
              GuideProfile.names[Random.secure().nextInt(
                GuideProfile.names.length,
              )];
          await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => GuideIntroSheet(
              initialName: initial,
              editing: true,
              onSave: (name) async {
                await ref.read(guideRepositoryProvider).save(name);
                ref.invalidate(guideNameProvider);
              },
            ),
          );
        },
      ),
    );
  }
}
