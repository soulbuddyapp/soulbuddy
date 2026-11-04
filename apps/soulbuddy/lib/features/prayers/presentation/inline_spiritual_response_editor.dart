import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../goals/domain/goal.dart';
import '../../goals/providers/goal_providers.dart';
import '../domain/library_prayer.dart';
import '../providers/personal_prayer_providers.dart';

class InlineSpiritualResponseEditor extends ConsumerStatefulWidget {
  const InlineSpiritualResponseEditor({
    required this.title,
    required this.initialText,
    required this.editorKey,
    required this.prayer,
    required this.enabled,
    required this.onCancel,
    super.key,
  });
  final String title;
  final String initialText;
  final Key editorKey;
  final bool prayer;
  final bool enabled;
  final VoidCallback onCancel;

  @override
  ConsumerState<InlineSpiritualResponseEditor> createState() =>
      InlineSpiritualResponseEditorState();
}

class InlineSpiritualResponseEditorState
    extends ConsumerState<InlineSpiritualResponseEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText,
  );
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving || _saved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.prayer) {
        final repo = await ref.read(personalPrayerRepositoryProvider.future);
        await repo.createOwnWords(
          title: String.fromCharCodes(widget.title.runes.take(120)),
          body: text,
          purpose: PrayerPurpose.guidance,
        );
        if (mounted) ref.invalidate(personalPrayersProvider);
      } else {
        final repo = await ref.read(goalRepositoryProvider.future);
        await repo.create(title: text, mode: GoalMode.actionable);
        if (mounted) {
          ref.invalidate(activeGoalsProvider);
          ref.invalidate(visibleGoalsProvider);
        }
      }
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) return Text(widget.prayer ? 'Prayer saved' : 'Goal saved');
    return Column(
      key: widget.editorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          enabled: widget.enabled && !_saving,
          minLines: 1,
          maxLines: 4,
          maxLength: widget.prayer ? null : 120,
          decoration: InputDecoration(
            labelText: widget.prayer ? 'Prayer' : 'Goal',
          ),
        ),
        if (_error != null) Text(_error!),
        Wrap(
          children: [
            FilledButton(
              onPressed: widget.enabled && !_saving ? _save : null,
              child: Text(widget.prayer ? 'Save prayer' : 'Save goal'),
            ),
            TextButton(
              onPressed: _saving ? null : widget.onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}
