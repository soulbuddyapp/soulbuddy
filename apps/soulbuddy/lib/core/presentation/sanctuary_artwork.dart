import 'package:flutter/material.dart';

import '../design/app_type.dart';
import 'sacred_surface.dart';

abstract final class SanctuaryArt {
  static const ascent = 'assets/images/sanctuary/ascent.png';
  static const prayer = 'assets/images/sanctuary/prayer.png';
  static const scripture = 'assets/images/sanctuary/scripture.png';
  static const renewal = 'assets/images/sanctuary/renewal.png';
}

class SanctuaryArch extends StatelessWidget {
  const SanctuaryArch({
    this.height = 320,
    this.caption = 'from glory\nto glory',
    super.key,
  });
  final double height;
  final String caption;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(
      top: Radius.circular(150),
      bottom: Radius.circular(26),
    );
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFA), Color(0xFFB7A58B), Color(0xFFF8F0DE)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55726043),
            blurRadius: 18,
            offset: Offset(4, 10),
          ),
          BoxShadow(color: Color(0x66FFE3A7), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              SanctuaryArt.ascent,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xEDF5E8D0),
                  ],
                  stops: [0, 0.62, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppType.displayFontFamily,
                  fontSize: 23,
                  height: 1.12,
                  color: Color(0xFF493621),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SanctuaryPracticeTile extends StatelessWidget {
  const SanctuaryPracticeTile({
    required this.art,
    required this.title,
    required this.onTap,
    super.key,
  });
  final String art;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SacredSurface(
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 83,
              child: Image.asset(
                art,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15),
                excludeFromSemantics: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SanctuaryReadingHeading extends StatelessWidget {
  const SanctuaryReadingHeading({
    required this.title,
    required this.art,
    this.subtitle,
    super.key,
  });
  final String title;
  final String art;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SacredSurface(
    marble: true,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.asset(
              art,
              width: 66,
              height: 80,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
