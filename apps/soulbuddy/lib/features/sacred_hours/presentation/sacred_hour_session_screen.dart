import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../persons/providers/person_providers.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../application/sacred_hour_session_controller.dart';
import '../domain/sacred_hour.dart';
import '../providers/sacred_hour_providers.dart';

class SacredHourSessionScreen extends ConsumerStatefulWidget {
  const SacredHourSessionScreen({
    required this.hourId,
    this.occurrenceKey,
    super.key,
  });

  final String hourId;
  final String? occurrenceKey;

  @override
  ConsumerState<SacredHourSessionScreen> createState() =>
      _SacredHourSessionScreenState();
}

class _SacredHourSessionScreenState
    extends ConsumerState<SacredHourSessionScreen> {
  SacredHourSessionController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = ref.watch(sacredHourProvider(widget.hourId));
    return hour.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _Unavailable(),
      data: (value) {
        if (value == null) return const _Unavailable();
        _controller ??= SacredHourSessionController(
          prayerMinutes: value.prayerMinutes,
        );
        final prayerTitle = _prayerTitle(ref, value.prayer);
        final personName = value.personId == null
            ? null
            : ref.watch(prayerPersonProvider(value.personId!)).value?.name;
        return SacredHourSessionView(
          hour: value,
          controller: _controller!,
          prayerTitle: prayerTitle,
          personName: personName,
          onOpenPrayer: value.prayer == null
              ? null
              : () => _openPrayer(context, value.prayer!),
          onOpenPerson: value.personId == null
              ? null
              : () => context.push('/persons/${value.personId}'),
          onRecordPrayer: () => _recordPrayer(value),
          onRemember: (mode) => context.push(
            '/remember/capture?mode=$mode&source=sacred-hour'
            '${value.personId == null ? '' : '&person=${value.personId}'}',
          ),
        );
      },
    );
  }

  Future<void> _recordPrayer(SacredHour hour) async {
    final prayer = hour.prayer;
    String? prayerSessionId;
    if (prayer != null) {
      String? revisionId;
      if (prayer.source == PrayerSource.personal) {
        final personal = await ref
            .read(personalPrayerRepositoryProvider.future)
            .then((repository) => repository.watch(prayer.id).first);
        revisionId = personal?.currentRevisionId;
      }
      final session = await ref
          .read(prayerPracticeRepositoryProvider.future)
          .then(
            (repository) => repository.recordSession(
              prayer: prayer,
              timezone: hour.timezone,
              revisionId: revisionId,
              idempotencyKey: widget.occurrenceKey,
            ),
          );
      prayerSessionId = session.id;
    }
    if (hour.personId case final personId?) {
      await ref
          .read(personRepositoryProvider.future)
          .then(
            (repository) =>
                repository.recordPrayer(personId, localDate: DateTime.now()),
          );
    }
    final dueAt = _dueAt(hour.id, widget.occurrenceKey) ?? DateTime.now();
    await ref
        .read(sacredHourRepositoryProvider.future)
        .then(
          (repository) => repository.markOccurrence(
            hour.id,
            dueAt,
            SacredHourOccurrenceStatus.completed,
            prayerSessionId: prayerSessionId,
          ),
        );
  }
}

class SacredHourSessionView extends StatefulWidget {
  const SacredHourSessionView({
    required this.hour,
    required this.controller,
    required this.onRecordPrayer,
    required this.onRemember,
    this.prayerTitle,
    this.personName,
    this.onOpenPrayer,
    this.onOpenPerson,
    super.key,
  });

  final SacredHour hour;
  final SacredHourSessionController controller;
  final Future<void> Function() onRecordPrayer;
  final ValueChanged<String> onRemember;
  final String? prayerTitle;
  final String? personName;
  final VoidCallback? onOpenPrayer;
  final VoidCallback? onOpenPerson;

  @override
  State<SacredHourSessionView> createState() => _SacredHourSessionViewState();
}

class _SacredHourSessionViewState extends State<SacredHourSessionView> {
  Timer? _ticker;
  var _quiet = false;
  var _selectedPrompt = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.beginPrayer();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(title: Text(widget.hour.name)),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: state.phase == SacredHourSessionPhase.prayer
                  ? _prayerPhase(context)
                  : _workPhase(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _prayerPhase(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = widget.controller.remaining;
    final totalSeconds = (remaining.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds.remainder(60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Begin with prayer', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$minutes:${seconds.toString().padLeft(2, '0')}',
          style: theme.textTheme.displaySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.prayerTitle case final title?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(title),
            trailing: TextButton(
              onPressed: widget.onOpenPrayer,
              child: const Text('Open prayer'),
            ),
          ),
        if (widget.personName case final name?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text('Pray for $name'),
            trailing: TextButton(
              onPressed: widget.onOpenPerson,
              child: const Text('Open'),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _quiet = !_quiet),
          icon: const Icon(Icons.self_improvement_outlined),
          label: Text(_quiet ? 'Stay here quietly' : 'Quiet prayer'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: widget.controller.state.prayerRecorded
              ? null
              : () => widget.controller.recordPrayer(widget.onRecordPrayer),
          child: Text(
            widget.controller.state.prayerRecorded
                ? 'Prayer recorded'
                : 'I prayed',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: widget.controller.continueToWork,
          child: const Text('Continue to work'),
        ),
      ],
    );
  }

  Widget _workPhase(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Carry the hour with God', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        const Text('Continue with the work already before you.'),
        const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < _workPrompts.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ChoiceChip(
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(_workPrompts[index], maxLines: 2, softWrap: true),
              ),
              selected: _selectedPrompt == index,
              onSelected: (_) => setState(() => _selectedPrompt = index),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Remember what I understood', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => widget.onRemember('speak'),
                icon: const Icon(Icons.mic_none),
                label: const Text('Speak'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => widget.onRemember('write'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Write'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

const _workPrompts = [
  'Why might God have placed me in this work?',
  'Who can I serve through it today?',
  'What needs patience, courage, honesty, or care?',
  'What may God be teaching me here?',
];

String? _prayerTitle(WidgetRef ref, PrayerReference? prayer) {
  if (prayer == null) return null;
  return switch (prayer.source) {
    PrayerSource.library => ref.watch(prayerProvider(prayer.id)).value?.title,
    PrayerSource.personal =>
      ref.watch(personalPrayerProvider(prayer.id)).value?.title,
  };
}

void _openPrayer(BuildContext context, PrayerReference prayer) {
  final path = prayer.source == PrayerSource.personal
      ? '/prayers/saved/${prayer.id}'
      : '/prayers/${prayer.id}';
  context.push(path);
}

DateTime? _dueAt(String hourId, String? occurrenceKey) {
  if (occurrenceKey == null) return null;
  final prefix = '$hourId@';
  if (!occurrenceKey.startsWith(prefix)) return null;
  return DateTime.tryParse(occurrenceKey.substring(prefix.length));
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('This Sacred Hour is unavailable.')),
  );
}
