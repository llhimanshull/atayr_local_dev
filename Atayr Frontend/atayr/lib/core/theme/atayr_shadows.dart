import 'package:flutter/material.dart';
import 'atayr_colors.dart';

class AtayrShadows {
  /// Standard Neo-brutalist shadow (4px 4px 0 black)
  static const List<BoxShadow> standard = [
    BoxShadow(
      color: AtayrColors.ink,
      offset: Offset(4, 4),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// Large Neo-brutalist shadow for primary CTAs (6px 6px 0 black)
  static const List<BoxShadow> large = [
    BoxShadow(
      color: AtayrColors.ink,
      offset: Offset(6, 6),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];
  
  /// No shadow (for pressed state)
  static const List<BoxShadow> none = [];
}
