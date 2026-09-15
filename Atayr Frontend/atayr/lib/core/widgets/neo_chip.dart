import 'package:flutter/material.dart';
import '../theme/atayr_colors.dart';
import '../theme/atayr_shadows.dart';

class NeoChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const NeoChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AtayrColors.accent : AtayrColors.background,
          border: Border.all(color: AtayrColors.ink, width: 2),
          boxShadow: isSelected ? AtayrShadows.none : AtayrShadows.standard,
        ),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
