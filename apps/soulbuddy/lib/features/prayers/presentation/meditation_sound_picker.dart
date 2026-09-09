import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/meditation_session.dart';

class MeditationSoundPicker extends StatelessWidget {
  const MeditationSoundPicker({
    required this.selected,
    required this.onSelected,
    this.onPreview,
    super.key,
  });

  final MeditationSoundBed? selected;
  final Future<void> Function(MeditationSoundBed? value) onSelected;
  final Future<void> Function(MeditationSoundBed value)? onPreview;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('meditation-sound-picker'),
    margin: EdgeInsets.zero,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.music_note_outlined),
      title: const Text('Background sound'),
      subtitle: Text(selected?.label ?? 'No background sound'),
      trailing: const Icon(Icons.expand_more),
      onTap: () => _showPicker(context),
    ),
  );

  Future<void> _showPicker(BuildContext context) async {
    final value = await showModalBottomSheet<Object>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _SoundPickerSheet(selected: selected, onPreview: onPreview),
    );
    if (!context.mounted) return;
    if (value == null) {
      await onSelected(selected);
      return;
    }
    final next = value == _noSound ? null : value as MeditationSoundBed;
    await onSelected(next);
  }
}

class _SoundPickerSheet extends StatelessWidget {
  const _SoundPickerSheet({required this.selected, required this.onPreview});

  final MeditationSoundBed? selected;
  final Future<void> Function(MeditationSoundBed value)? onPreview;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.78,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        Text(
          'Choose background sound',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        _choice(context, value: _noSound, title: 'No background sound'),
        _group(context, 'Quiet ambience', MeditationSoundCategory.quiet),
        _group(
          context,
          'Motivational music',
          MeditationSoundCategory.motivational,
        ),
      ],
    ),
  );

  Widget _group(
    BuildContext context,
    String title,
    MeditationSoundCategory category,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, 0, 0),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      for (final sound in MeditationSoundBed.values.where(
        (value) => value.category == category,
      ))
        _choice(
          context,
          value: sound,
          title: sound.label,
          secondary: IconButton(
            tooltip: 'Preview ${sound.label}',
            onPressed: onPreview == null
                ? null
                : () => unawaited(onPreview!(sound)),
            icon: const Icon(Icons.play_circle_outline),
          ),
        ),
    ],
  );

  Widget _choice(
    BuildContext context, {
    required Object value,
    required String title,
    Widget? secondary,
  }) {
    final isSelected = value == (selected ?? _noSound);
    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        title: Text(title),
        trailing: secondary,
        onTap: () => Navigator.pop(context, value),
      ),
    );
  }
}

const _noSound = Object();
