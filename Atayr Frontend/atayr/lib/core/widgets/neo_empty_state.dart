import 'package:flutter/material.dart';
import '../theme/atayr_colors.dart';
import '../theme/atayr_shadows.dart';

class NeoEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onCtaPressed;

  const NeoEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AtayrColors.surface,
        border: Border.all(color: AtayrColors.ink, width: 2),
        boxShadow: AtayrShadows.standard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            message.toUpperCase(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Primary CTA embedded in empty state
          GestureDetector(
            onTap: onCtaPressed,
            child: Container(
              decoration: BoxDecoration(
                color: AtayrColors.accent,
                border: Border.all(color: AtayrColors.ink, width: 2),
                boxShadow: AtayrShadows.standard,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  ctaLabel.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
