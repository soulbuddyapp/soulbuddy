import 'package:flutter/material.dart';
import '../../../core/speech/sayable_field.dart';
import '../../guide/presentation/guide_illustration.dart';
import '../domain/formation_catalog.dart';
import '../domain/formation_progress.dart';
import '../domain/teaching_reflection_prompts.dart';

class TeachingReflectionSheet extends StatefulWidget {
  const TeachingReflectionSheet({
    super.key,
    required this.day,
    required this.videoId,
    required this.guideName,
    required this.onSave,
  });
  final FormationDay day;
  final String videoId;
  final String? guideName;
  final Future<void> Function(FormationCompletion) onSave;
  @override
  State<TeachingReflectionSheet> createState() =>
      _TeachingReflectionSheetState();
}

class _TeachingReflectionSheetState extends State<TeachingReflectionSheet> {
  final reflection = TextEditingController();
  final action = TextEditingController();
  bool saving = false;
  bool failed = false;
  @override
  void dispose() {
    reflection.dispose();
    action.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.onSave(
        FormationCompletion(
          day: widget.day.day,
          videoId: widget.videoId,
          completedAt: DateTime.now(),
          reflection: reflection.text,
          action: action.text,
        ),
      );
      if (mounted) {
        setState(() => saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (question, practical) = teachingPrompts(widget.day);
    return PopScope(
      canPop: !saving,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const GuideIllustration(),
            if (widget.guideName != null)
              Center(
                child: Text(
                  widget.guideName!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Private reflection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SayableField(
              controller: reflection,
              maxLines: 3,
              labelText: 'Your thoughts',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Text(practical, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SayableField(
              controller: action,
              maxLines: 2,
              labelText: 'Your next step',
              showUnavailableNotice: false,
            ),
            if (failed)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Could not save. Try again.'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving ? null : save,
              child: const Text('Complete today'),
            ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
