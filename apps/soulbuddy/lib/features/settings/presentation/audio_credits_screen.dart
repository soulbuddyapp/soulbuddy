import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AudioCreditsScreen extends StatelessWidget {
  const AudioCreditsScreen({super.key});
  Future<void> _open(BuildContext context, String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* An unavailable browser must not break Settings. */
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link unavailable. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audio credits')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Commitment invitation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const SelectableText(
            '“Aphelion” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au',
          ),
          const SizedBox(height: 8),
          const Text(
            'Excerpt: 1:45–2:15. Trimmed, normalized and faded for the invitation.',
          ),
          TextButton(
            onPressed: () => _open(
              context,
              'https://www.scottbuckley.com.au/library/aphelion/',
            ),
            child: const Text('Artist and original recording'),
          ),
          TextButton(
            onPressed: () =>
                _open(context, 'https://creativecommons.org/licenses/by/4.0/'),
            child: const Text('CC BY 4.0 license'),
          ),
          const Divider(),
          Text(
            'Meditation music',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final track in const [
            ('Resolutions', 'resolutions'),
            ('Aurora', 'aurora'),
            ('Affirmations', 'affirmations'),
            ('First Snow', 'first-snow'),
            ('A Kind Of Hope', 'a-kind-of-hope'),
          ]) ...[
            SelectableText(
              '“${track.$1}” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au',
            ),
            TextButton(
              onPressed: () => _open(
                context,
                'https://www.scottbuckley.com.au/library/${track.$2}/',
              ),
              child: Text('${track.$1} · original recording'),
            ),
          ],
          const Text(
            'Excerpts edited into continuous loops and loudness normalized.',
          ),
          TextButton(
            onPressed: () =>
                _open(context, 'https://creativecommons.org/licenses/by/4.0/'),
            child: const Text('CC BY 4.0 license'),
          ),
          const Divider(),
          Text('Narration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'SoulBuddy devotional scripts, narrated with a synthetic voice. Psalm 46:10: RSVCE.',
          ),
        ],
      ),
    ),
  );
}
