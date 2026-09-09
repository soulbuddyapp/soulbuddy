import 'package:flutter/material.dart';

/// The visual meaning assigned to the app's spiritual experiences.
enum SacredPiece {
  today,
  prayer,
  goal,
  person,
  remember,
  altar,
  circle,
  scripture,
  meditation,
  sacredHour,
  orientation;

  String get semanticLabel => switch (this) {
    SacredPiece.today => 'Today',
    SacredPiece.prayer => 'Prayer',
    SacredPiece.goal => 'Goal',
    SacredPiece.person => 'Person',
    SacredPiece.remember => 'Remember',
    SacredPiece.altar => 'Altar',
    SacredPiece.circle => 'Circle',
    SacredPiece.scripture => 'Scripture',
    SacredPiece.meditation => 'Meditation',
    SacredPiece.sacredHour => 'Sacred Hour',
    SacredPiece.orientation => 'Orientation',
  };

  IconData get icon => switch (this) {
    SacredPiece.today => Icons.wb_sunny_outlined,
    SacredPiece.prayer => Icons.volunteer_activism_outlined,
    SacredPiece.goal => Icons.explore_outlined,
    SacredPiece.person => Icons.person_outline,
    SacredPiece.remember => Icons.bookmark_border,
    SacredPiece.altar => Icons.local_fire_department_outlined,
    SacredPiece.circle => Icons.groups_2_outlined,
    SacredPiece.scripture => Icons.menu_book_outlined,
    SacredPiece.meditation => Icons.self_improvement_outlined,
    SacredPiece.sacredHour => Icons.wb_twilight_outlined,
    SacredPiece.orientation => Icons.route_outlined,
  };

  IconData get selectedIcon => switch (this) {
    SacredPiece.today => Icons.wb_sunny,
    SacredPiece.prayer => Icons.volunteer_activism,
    SacredPiece.goal => Icons.explore,
    SacredPiece.person => Icons.person,
    SacredPiece.remember => Icons.bookmark,
    SacredPiece.altar => Icons.local_fire_department,
    SacredPiece.circle => Icons.groups_2,
    SacredPiece.scripture => Icons.menu_book,
    SacredPiece.meditation => Icons.self_improvement,
    SacredPiece.sacredHour => Icons.wb_twilight,
    SacredPiece.orientation => Icons.route,
  };
}
