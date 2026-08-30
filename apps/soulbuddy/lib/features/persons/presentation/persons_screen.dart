import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/prayer_person.dart';
import '../providers/person_providers.dart';

class PersonsScreen extends ConsumerWidget {
  const PersonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(prayerPeopleProvider);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Persons',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('add-person-icon'),
                      tooltip: 'Add a person',
                      onPressed: () => context.push('/persons/new'),
                      icon: const Icon(Icons.person_add_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Keep the people in your life before God.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: people.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _PersonsUnavailable(
                      onRetry: () => ref.invalidate(prayerPeopleProvider),
                    ),
                    data: (items) => items.isEmpty
                        ? const _PersonsEmptyState()
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) => _PersonCard(
                              person: items[index],
                              onTap: () =>
                                  context.push('/persons/${items[index].id}'),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonsEmptyState extends StatelessWidget {
  const _PersonsEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Who would you like to remember in prayer?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('add-first-person'),
            onPressed: () => context.push('/persons/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add a person'),
          ),
        ],
      ),
    ),
  );
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onTap});

  final PrayerPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(person.name.characters.first.toUpperCase()),
      ),
      title: Text(person.name),
      subtitle: Text(
        [
          if (person.relationship != null) person.relationship,
          _cadenceLabel(person),
        ].whereType<String>().join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

String _cadenceLabel(PrayerPerson person) => switch (person.cadence) {
  PersonPrayerCadence.daily => 'Daily',
  PersonPrayerCadence.weekly => 'Weekly',
  PersonPrayerCadence.selectedDays => 'Selected days',
};

class _PersonsUnavailable extends StatelessWidget {
  const _PersonsUnavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Your persons could not be opened just now.'),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
