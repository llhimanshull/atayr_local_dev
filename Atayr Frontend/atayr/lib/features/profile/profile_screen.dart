import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_card.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/theme/atayr_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return SafeArea(
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        body: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const SizedBox(height: 16),
            const NeoSectionHeader(title: 'PROFILE'),
            const SizedBox(height: 24),
            
            NeoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ACCOUNT INFORMATION',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'EMAIL',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AtayrColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Not logged in',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'USER ID',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AtayrColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.id ?? 'N/A',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              child: NeoButton(
                label: 'LOGOUT',
                isPrimary: false,
                onPressed: () {
                  context.read<AuthProvider>().signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
