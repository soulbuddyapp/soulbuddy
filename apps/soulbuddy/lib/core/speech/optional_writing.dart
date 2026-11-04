import 'package:flutter/material.dart';

import 'sayable_field.dart';

/// An optional written alternative alongside an inline recorder.
class OptionalWriting extends StatefulWidget {
  const OptionalWriting({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.maxLength = 4000,
    this.onChanged,
    this.onSave,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  final Future<void> Function(String)? onSave;

  @override
  State<OptionalWriting> createState() => _OptionalWritingState();
}

class _OptionalWritingState extends State<OptionalWriting> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text('Write ${widget.label.toLowerCase()}'),
    children: [
      SayableField(
        controller: widget.controller,
        labelText: widget.label,
        enabled: widget.enabled && !_saving,
        maxLines: 6,
        maxLength: widget.maxLength,
        onChanged: widget.onChanged,
      ),
      if (widget.onSave != null)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) => FilledButton(
            onPressed: !widget.enabled || _saving || value.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await widget.onSave!(value.text.trim());
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not save. Try again.'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: const Text('Continue'),
          ),
        ),
    ],
  );
}
