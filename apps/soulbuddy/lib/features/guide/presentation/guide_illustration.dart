import 'package:flutter/material.dart';

class GuideIllustration extends StatelessWidget {
  const GuideIllustration({super.key, this.height = 130});
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/images/guide/listening.png',
      height: height,
      errorBuilder: (_, _, _) => SizedBox(height: height),
    ),
  );
}
