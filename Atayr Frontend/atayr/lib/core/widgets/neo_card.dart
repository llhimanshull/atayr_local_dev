import 'package:flutter/material.dart';
import '../theme/atayr_colors.dart';
import '../theme/atayr_shadows.dart';

class NeoCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const NeoCard({
    super.key,
    required this.child,
    this.backgroundColor = AtayrColors.background,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: AtayrColors.ink, width: 2),
        boxShadow: AtayrShadows.standard,
      ),
      padding: padding,
      child: child,
    );
  }
}
