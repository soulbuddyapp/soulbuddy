import 'package:flutter/material.dart';
import '../domain/guide_profile.dart';
import 'guide_illustration.dart';

class GuideIntroSheet extends StatefulWidget {
  const GuideIntroSheet({
    super.key,
    required this.initialName,
    required this.onSave,
    this.editing = false,
  });
  final String initialName;
  final Future<void> Function(String) onSave;
  final bool editing;
  @override
  State<GuideIntroSheet> createState() => _GuideIntroSheetState();
}

class _GuideIntroSheetState extends State<GuideIntroSheet> {
  late final TextEditingController name = TextEditingController(
    text: widget.initialName,
  );
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!GuideProfile.validName(name.text)) {
      setState(() => error = 'Enter a name of 1–40 characters.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(name.text.trim());
      if (mounted) Navigator.pop(context, name.text.trim());
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GuideIllustration(height: 150),
        Text(
          widget.editing ? 'Guide name' : 'Meet your Guide',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(widget.editing ? 'Save' : 'Continue'),
        ),
        if (error != null && !widget.editing)
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context, ''),
            child: const Text('Continue without a name'),
          ),
      ],
    ),
  );
}
