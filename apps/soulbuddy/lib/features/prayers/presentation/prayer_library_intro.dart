import 'package:flutter/material.dart';

class PrayerLibraryIntro extends StatelessWidget {
  const PrayerLibraryIntro({required this.onForThisMoment, super.key});

  final VoidCallback onForThisMoment;

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
            value: _PrayerPath.forThisMoment,
            icon: largeText ? null : const Icon(Icons.edit_outlined),
            label: const SizedBox(
              key: Key('for-this-moment-choice'),
              height: 48,
              child: Center(child: Text('For this moment')),
            ),
          ),
        ],
        selected: const {_PrayerPath.library},
        onSelectionChanged: (selection) {
          if (selection.contains(_PrayerPath.forThisMoment)) {
            onForThisMoment();
          }
        },
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(0, 48)),
        ),
      ),
    );
  }
}

enum _PrayerPath { library, forThisMoment }
