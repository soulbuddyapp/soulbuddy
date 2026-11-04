import 'package:flutter/material.dart';

/// The one disclosure a person must accept before prayer text leaves this
/// device.
///
/// The reminder sheet and the Today reminder card both route through here, so
/// the wording cannot drift between the two surfaces and a control that offers
/// narration always offers this same consent first.
Future<bool> showPrayerNarrationDisclosure(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Prepare prayer narration?'),
      content: const Text(
        'Prayer narration uses Deepgram to create a private cached reading of this saved prayer.',
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
  return accepted == true;
}
