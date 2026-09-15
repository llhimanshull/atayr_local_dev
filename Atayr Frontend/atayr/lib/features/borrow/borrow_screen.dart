import 'package:flutter/material.dart';
import '../../core/widgets/neo_empty_state.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/theme/atayr_colors.dart';

class BorrowScreen extends StatelessWidget {
  const BorrowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        body: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const SizedBox(height: 16),
            const NeoSectionHeader(title: 'BORROW'),
            const SizedBox(height: 24),
            NeoEmptyState(
              title: 'COMING SOON',
              message: 'BORROWING FROM FRIENDS WILL BE AVAILABLE IN A FUTURE UPDATE.',
              ctaLabel: 'EXPLORE WARDROBE',
              onCtaPressed: () {
                // Future routing logic
              },
            ),
          ],
        ),
      ),
    );
  }
}
