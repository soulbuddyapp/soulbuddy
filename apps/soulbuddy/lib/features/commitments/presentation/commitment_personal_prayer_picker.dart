import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../providers/commitment_prayer_narration_providers.dart';

class CommitmentPersonalPrayerPicker extends ConsumerStatefulWidget {
  const CommitmentPersonalPrayerPicker({
    required this.onChanged,
    this.selectedPrayerId,
    this.selectedRevisionId,
    super.key,
  });
  final void Function(String? prayerId, String? revisionId) onChanged;
  final String? selectedPrayerId, selectedRevisionId;
  @override
  ConsumerState<CommitmentPersonalPrayerPicker> createState() =>
      _CommitmentPersonalPrayerPickerState();
}

class _CommitmentPersonalPrayerPickerState
    extends ConsumerState<CommitmentPersonalPrayerPicker> {
  bool _preparing = false;
  String? _message;
  @override
  Widget build(BuildContext context) {
    final prayers = ref.watch(personalPrayersProvider);
    return prayers.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Text(
        'Saved prayers are unavailable. The selected guide remains available.',
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final selected = items
            .where(
              (p) =>
                  p.id == widget.selectedPrayerId &&
                  p.currentRevisionId == widget.selectedRevisionId,
            )
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(widget.selectedPrayerId),
              initialValue: selected?.id ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Personal prayer (optional)',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('No personal prayer'),
                ),
                for (final prayer in items)
                  DropdownMenuItem(
                    value: prayer.id,
                    child: Text(prayer.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _preparing
                  ? null
                  : (id) {
                      setState(() => _message = null);
                      if (id == null || id.isEmpty) {
                        widget.onChanged(null, null);
                        return;
                      }
                      final prayer = items.firstWhere((p) => p.id == id);
                      widget.onChanged(prayer.id, prayer.currentRevisionId);
                    },
            ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              if (selected.body.runes.length <= 2000)
                TextButton.icon(
                  onPressed: _preparing
                      ? null
                      : () => _prepare(selected.id, selected.currentRevisionId),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: Text(
                    _preparing ? 'Preparing narration…' : 'Prepare narration',
                  ),
                )
              else
                const Text(
                  'Narration requires a prayer of 2,000 characters or fewer.',
                ),
            ],
            if (_message != null) Text(_message!),
          ],
        );
      },
    );
  }

  Future<void> _prepare(String prayerId, String revisionId) async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prepare prayer narration?'),
        content: const Text(
          'The selected prayer text will be sent to Deepgram to create narration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept and prepare'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    setState(() {
      _preparing = true;
      _message = null;
    });
    try {
      await ref.read(commitmentPreparePrayerProvider)(
        personalPrayerId: prayerId,
        revisionId: revisionId,
        consent: true,
      );
      if (mounted) setState(() => _message = 'Narration ready.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Narration is unavailable. The selected guide remains available.',
        );
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }
}
