import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/sacred_surface.dart';
import '../../../core/playback/spiritual_session_providers.dart';
import '../../../core/speech/sayable_field.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../application/formation_video_launcher.dart';
import '../domain/formation_catalog.dart';
import '../domain/formation_profile.dart';
import '../domain/formation_progress.dart';
import '../providers/daily_formation_providers.dart';

class DailyFormationCard extends ConsumerWidget {
  const DailyFormationCard({super.key});

  static final _videoLauncher = FormationVideoLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(dailyFormationCatalogProvider);
    final profile = ref.watch(dailyFormationProfileProvider);
    final progress = ref.watch(dailyFormationProgressProvider);
    if (catalog is! AsyncData<FormationCatalog> ||
        profile is! AsyncData<FormationProfile> ||
        progress is! AsyncData<FormationProgress>) {
      return const SizedBox.shrink();
    }
    if (!profile.value.ready) return _SetupCard(initial: profile.value);
    if (progress.value.currentDay > catalog.value.days.length) {
      return const SacredSurface(
        marble: true,
        child: Text('Continue growing through prayer and faithful action.'),
      );
    }
    final day = catalog.value.days[progress.value.currentDay - 1];
    final video = _selectedVideo(
      catalog.value,
      day,
      progress.value.selectedVideoId,
      profile.value.minutes,
    );
    final resources = day.resourceIds
        .map((id) => catalog.value.resourcesById[id])
        .whereType<FormationResource>()
        .toList();
    return SacredSurface(
      marble: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAY ${day.day} · ${_packTitle(catalog.value, day.packId)}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.3),
          ),
          const SizedBox(height: 8),
          Text(day.focus, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(day.scripture, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          _VideoTile(video: video),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _launch(context, ref, video),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Watch'),
              ),
              OutlinedButton(
                onPressed: () => _choose(context, ref, catalog.value, day),
                child: const Text('Choose another'),
              ),
              TextButton(
                onPressed: () => _complete(context, ref, day, video),
                child: const Text('Finish'),
              ),
            ],
          ),
          if (resources.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Resources', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final resource in resources)
              _ResourceTile(
                resource: resource,
                onTap: () => _launchResource(context, resource),
              ),
          ],
        ],
      ),
    );
  }

  FormationVideo _selectedVideo(
    FormationCatalog catalog,
    FormationDay day,
    String? selectedId,
    int minutes,
  ) {
    final options = day.videoIds
        .map((id) => catalog.videosById[id])
        .whereType<FormationVideo>()
        .toList();
    return options.firstWhere(
      (video) => video.id == selectedId,
      orElse: () => options.firstWhere(
        (video) => video.runtimeSeconds <= minutes * 60,
        orElse: () => options.first,
      ),
    );
  }

  String _packTitle(FormationCatalog catalog, String id) => catalog.packs
      .firstWhere((pack) => pack.id == id, orElse: () => catalog.packs.first)
      .title;

  Future<void> _launch(
    BuildContext context,
    WidgetRef ref,
    FormationVideo video,
  ) async {
    await ref.read(spiritualSessionControllerProvider).pauseForCapture();
    final opened = await _videoLauncher.open(
      youtubeId: video.youtubeId,
      webUrl: Uri.parse(video.youtubeUrl),
    );
    if (opened) recordDailyFormationOpened(ref, video.id);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The video could not be opened.')),
      );
    }
  }

  Future<void> _launchResource(
    BuildContext context,
    FormationResource resource,
  ) async {
    final opened = await _videoLauncher.open(
      youtubeId: resource.youtubeId,
      webUrl: Uri.parse(resource.youtubeUrl),
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The resource could not be opened.')),
      );
    }
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    FormationCatalog catalog,
    FormationDay day,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose today’s video',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final id in day.videoIds)
                  if (catalog.videosById[id] case final video?)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(video.title),
                      subtitle: Text(
                        '${video.channel} · ${_duration(video.runtimeSeconds)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await selectDailyFormationVideo(
                          ref,
                          day: day.day,
                          videoId: video.id,
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                    ),
                const Divider(),
                Text(
                  'More teaching',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final source in _formationSources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(source.name),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openSource(context, source.url);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSource(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      // Report a failed external launch with the same recovery message.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teaching could not be opened.')),
      );
    }
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    FormationDay day,
    FormationVideo video,
  ) async {
    final result =
        await showModalBottomSheet<
          ({String? recordingId, String action, String reflection})
        >(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => _CompletionSheet(day: day, video: video),
        );
    if (result == null) return;
    await completeDailyFormation(
      ref,
      FormationCompletion(
        day: day.day,
        videoId: video.id,
        completedAt: DateTime.now(),
        reflectionEncounterId: result.recordingId,
        reflection: result.reflection,
        action: result.action,
      ),
    );
    recordDailyFormationCompleted(ref, video.id);
  }

  static String _duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _FormationSource {
  const _FormationSource(this.name, this.url);
  final String name;
  final String url;
}

const _formationSources = [
  _FormationSource(
    'BibleProject',
    'https://www.youtube.com/user/jointhebibleproject',
  ),
  _FormationSource(
    'Fr. Mike Schmitz · Ascension',
    'https://www.youtube.com/@AscensionPresents',
  ),
  _FormationSource(
    'Dr. Myles Munroe · Munroe Global',
    'https://www.youtube.com/MunroeGlobal',
  ),
  _FormationSource(
    'RyanMakCC · practical skills',
    'https://www.youtube.com/@ryanmakcc',
  ),
];

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video});

  final FormationVideo video;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.play_circle_fill_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  '${video.channel} · ${DailyFormationCard._duration(video.runtimeSeconds)}',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.resource, required this.onTap});

  final FormationResource resource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resource.title),
                  Text(
                    resource.source,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _SetupCard extends ConsumerStatefulWidget {
  const _SetupCard({required this.initial});
  final FormationProfile initial;

  @override
  ConsumerState<_SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends ConsumerState<_SetupCard> {
  late int _minutes;
  TimeOfDay? _reminder;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initial.minutes;
    _reminder = widget.initial.hasReminder
        ? TimeOfDay(
            hour: widget.initial.reminderHour!,
            minute: widget.initial.reminderMinute!,
          )
        : null;
  }

  @override
  Widget build(BuildContext context) => SacredSurface(
    marble: true,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DAILY FORMATION', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Text(
          'Set a daily rhythm',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Choose the time you can offer each day.'),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 5, label: Text('5 min')),
            ButtonSegment(value: 10, label: Text('10 min')),
            ButtonSegment(value: 15, label: Text('15 min')),
          ],
          selected: {_minutes},
          onSelectionChanged: (value) =>
              setState(() => _minutes = value.single),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _reminder ?? TimeOfDay.now(),
            );
            if (picked != null && mounted) setState(() => _reminder = picked);
          },
          icon: const Icon(Icons.notifications_outlined),
          label: Text(
            _reminder == null
                ? 'Add a daily reminder'
                : 'Reminder ${_reminder!.format(context)}',
          ),
        ),
        FilledButton(
          onPressed: () async {
            await saveDailyFormationProfile(
              ref,
              FormationProfile(
                ready: true,
                minutes: _minutes,
                reminderHour: _reminder?.hour,
                reminderMinute: _reminder?.minute,
              ),
            );
            if (_reminder != null) {
              final coordinator = await ref.read(
                dailyFormationReminderCoordinatorProvider.future,
              );
              await coordinator.enableOnThisDevice();
            }
          },
          child: const Text('Begin daily formation'),
        ),
      ],
    ),
  );
}

class _CompletionSheet extends StatefulWidget {
  const _CompletionSheet({required this.day, required this.video});
  final FormationDay day;
  final FormationVideo video;

  @override
  State<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends State<_CompletionSheet> {
  String? _recordingId;
  bool _recordingBusy = false;
  final _action = TextEditingController();
  final _reflection = TextEditingController();

  @override
  void dispose() {
    _action.dispose();
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_recordingBusy,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'After watching',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            VoiceNotesField(
              noteContext: (
                type: 'formation',
                id: '${widget.video.id}:day-${widget.day.day}',
                field: 'reflection',
              ),
              title: widget.video.title,
              onRecorded: (memory) {
                if (mounted) setState(() => _recordingId = memory.id);
              },
              onBusyChanged: (busy) {
                if (mounted) setState(() => _recordingBusy = busy);
              },
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Write reflection'),
              children: [
                SayableField(
                  controller: _reflection,
                  enabled: !_recordingBusy,
                  labelText: 'Reflection',
                  maxLines: 4,
                ),
              ],
            ),
            SayableField(
              controller: _action,
              enabled: !_recordingBusy,
              showUnavailableNotice: false,
              maxLength: 80,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Next step · short title',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _recordingBusy
                  ? null
                  : () => Navigator.pop(context, (
                      recordingId: _recordingId,
                      action: _action.text,
                      reflection: _reflection.text,
                    )),
              child: const Text('Complete today'),
            ),
            TextButton(
              onPressed: _recordingBusy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
