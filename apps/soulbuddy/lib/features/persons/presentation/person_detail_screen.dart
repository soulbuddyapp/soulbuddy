import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../record/presentation/inline_memory_recorder.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../application/person_prayer_guide.dart';
import '../domain/prayer_person.dart';
import '../providers/person_providers.dart';

class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(prayerPersonProvider(personId))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => _Unavailable(
          onRetry: () => ref.invalidate(prayerPersonProvider(personId)),
        ),
        data: (person) => person == null
            ? const Scaffold(body: Center(child: Text('Person not found.')))
            : _PersonDetail(person: person),
      );
}

class _PersonDetail extends ConsumerStatefulWidget {
  const _PersonDetail({required this.person});

  final PrayerPerson person;

  @override
  ConsumerState<_PersonDetail> createState() => _PersonDetailState();
}

class _PersonDetailState extends ConsumerState<_PersonDetail> {
  bool _recordingBusy = false;
  PrayerPerson get person => widget.person;

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(personLinkedMemoriesProvider(person.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Person'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: _recordingBusy
                ? null
                : () => context.push('/persons/${person.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            enabled: !_recordingBusy,
            onSelected: (value) {
              if (value == 'archive') _archive(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'archive', child: Text('Archive person')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                        person.name.characters.first.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (person.relationship case final value?)
                            Text(value),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  key: const Key('prayed-for-person'),
                  onPressed: _recordingBusy
                      ? null
                      : () => _openPrayerGuide(context, ref),
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: Text('Pray for ${person.name}'),
                ),
                const SizedBox(height: AppSpacing.sm),
                InlineMemoryRecorder(
                  buttonKey: const Key('remember-person'),
                  label: 'Remember something about them',
                  initialPersonIds: [person.id],
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _recordingBusy = busy);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _scheduleDescription(person),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Remembered with them',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                memories.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) =>
                      const Text('Memories could not be opened just now.'),
                  data: (items) => items.isEmpty
                      ? const Text('No linked memories yet.')
                      : Column(
                          children: [
                            for (final memory in items)
                              Card(
                                child: ListTile(
                                  onTap: _recordingBusy
                                      ? null
                                      : () => context.push(
                                          '/remember/${memory.id}',
                                        ),
                                  leading: const Icon(Icons.bookmark_outline),
                                  title: Text(
                                    memory.sensitive
                                        ? 'Private memory'
                                        : memory.title,
                                  ),
                                  subtitle: Text(memory.occurredOn),
                                  trailing: const Icon(Icons.chevron_right),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recordPrayer(BuildContext context, WidgetRef ref) async {
    try {
      final repository = await ref.read(personRepositoryProvider.future);
      final occurrence = await repository.recordPrayer(
        person.id,
        localDate: DateTime.now(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            occurrence == null
                ? 'Already remembered today.'
                : 'Prayer remembered.',
          ),
        ),
      );
      ref.invalidate(
        duePersonPrayersProvider(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record this just now.')),
        );
      }
    }
  }

  Future<void> _openPrayerGuide(BuildContext context, WidgetRef ref) async {
    final prayed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PersonPrayerGuide(person: person),
    );
    if (prayed == true && context.mounted) {
      await _recordPrayer(context, ref);
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this person?'),
        content: const Text('Their saved memories will remain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = await ref.read(personRepositoryProvider.future);
    await repository.archive(person.id);
    ref.invalidate(prayerPeopleProvider);
    if (context.mounted) context.go('/persons');
  }
}

class _PersonPrayerGuide extends StatefulWidget {
  const _PersonPrayerGuide({required this.person});

  final PrayerPerson person;

  @override
  State<_PersonPrayerGuide> createState() => _PersonPrayerGuideState();
}

class _PersonPrayerGuideState extends State<_PersonPrayerGuide> {
  late final TextEditingController _words = TextEditingController(
    text: personPrayerGuide(widget.person.name),
  );

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + inset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pray for ${widget.person.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('person-prayer-guide-words'),
              controller: _words,
              minLines: 7,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Prayer guide',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('person-prayer-guide-complete'),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: Text('I prayed for ${widget.person.name}'),
            ),
          ],
        ),
      ),
    );
  }
}

String _scheduleDescription(PrayerPerson person) {
  final cadence = switch (person.cadence) {
    PersonPrayerCadence.daily => 'Daily',
    PersonPrayerCadence.weekly => 'Weekly',
    PersonPrayerCadence.selectedDays => 'On selected days',
  };
  return person.localTime == null ? cadence : '$cadence · ${person.localTime}';
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: onRetry, child: const Text('Try again')),
    ),
  );
}
