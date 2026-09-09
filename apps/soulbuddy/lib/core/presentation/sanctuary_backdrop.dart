import 'package:flutter/material.dart';

/// A quiet light field shared by the sanctuary and its reading spaces.
class SanctuaryBackdrop extends StatelessWidget {
  const SanctuaryBackdrop({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.35, -0.85),
          radius: 1.4,
          colors: dark
              ? const [Color(0xFF483A27), Color(0xFF211D19)]
              : const [Color(0xFFFFF8E7), Color(0xFFE8E0D4), Color(0xFFD4C8B9)],
          stops: dark ? null : const [0, 0.56, 1],
        ),
      ),
      child: child,
    );
  }
}
