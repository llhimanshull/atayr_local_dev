import 'package:flutter/material.dart';
import '../theme/atayr_colors.dart';

class NeoSectionHeader extends StatelessWidget {
  final String title;

  const NeoSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AtayrColors.ink, width: 3),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          height: 1.1,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
