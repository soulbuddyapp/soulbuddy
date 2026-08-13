import 'package:flutter/material.dart';

/// Semantic colors for SoulBuddy's sacred, natural-slab visual language.
@immutable
class CovenantGraceColors extends ThemeExtension<CovenantGraceColors> {
  const CovenantGraceColors({
    required this.parchment,
    required this.limestone,
    required this.limestoneLight,
    required this.umber,
    required this.covenantGold,
    required this.lightWash,
  });

  static const light = CovenantGraceColors(
    parchment: Color(0xFFF7F1E5),
    limestone: Color(0xFFC9BCA5),
    limestoneLight: Color(0xFFE7DDCB),
    umber: Color(0xFF62513F),
    covenantGold: Color(0xFFB5893E),
    lightWash: Color(0xFFF1DFB7),
  );

  static const dark = CovenantGraceColors(
    parchment: Color(0xFF171B18),
    limestone: Color(0xFF756B5B),
    limestoneLight: Color(0xFF9B8E78),
    umber: Color(0xFFE1D4BF),
    covenantGold: Color(0xFFD6AB60),
    lightWash: Color(0xFF4A3C25),
  );

  final Color parchment;
  final Color limestone;
  final Color limestoneLight;
  final Color umber;
  final Color covenantGold;
  final Color lightWash;

  @override
  CovenantGraceColors copyWith({
    Color? parchment,
    Color? limestone,
    Color? limestoneLight,
    Color? umber,
    Color? covenantGold,
    Color? lightWash,
  }) {
    return CovenantGraceColors(
      parchment: parchment ?? this.parchment,
      limestone: limestone ?? this.limestone,
      limestoneLight: limestoneLight ?? this.limestoneLight,
      umber: umber ?? this.umber,
      covenantGold: covenantGold ?? this.covenantGold,
      lightWash: lightWash ?? this.lightWash,
    );
  }

  @override
  CovenantGraceColors lerp(covariant CovenantGraceColors? other, double t) {
    if (other == null) {
      return this;
    }
    return CovenantGraceColors(
      parchment: Color.lerp(parchment, other.parchment, t)!,
      limestone: Color.lerp(limestone, other.limestone, t)!,
      limestoneLight: Color.lerp(limestoneLight, other.limestoneLight, t)!,
      umber: Color.lerp(umber, other.umber, t)!,
      covenantGold: Color.lerp(covenantGold, other.covenantGold, t)!,
      lightWash: Color.lerp(lightWash, other.lightWash, t)!,
    );
  }
}
