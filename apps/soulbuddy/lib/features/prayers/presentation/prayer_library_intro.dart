import 'package:flutter/material.dart';

class PrayerLibraryIntro extends StatelessWidget {
  const PrayerLibraryIntro({required this.onPersonalized, super.key});

  final VoidCallback onPersonalized;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_PrayerPath>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: _PrayerPath.library,
            icon: largeText ? null : const Icon(Icons.menu_book_outlined),
            label: const SizedBox(
              key: Key('library-choice'),
              height: 48,
              child: Center(child: Text('Library')),
            ),
          ),
          ButtonSegment(
            value: _PrayerPath.personalized,
            icon: largeText ? null : const Icon(Icons.edit_outlined),
            label: const SizedBox(
              key: Key('personalized-choice'),
              height: 48,
              child: Center(child: Text('Personalized')),
            ),
          ),
        ],
        selected: const {_PrayerPath.library},
        onSelectionChanged: (selection) {
          if (selection.contains(_PrayerPath.personalized)) onPersonalized();
        },
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(0, 48)),
        ),
      ),
    );
  }
}

enum _PrayerPath { library, personalized }
