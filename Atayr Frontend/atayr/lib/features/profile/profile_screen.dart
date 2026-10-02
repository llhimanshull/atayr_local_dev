import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_card.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_input.dart';
import '../../services/profile_service.dart';
import '../friends/friends_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  String? _displayName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _profileService.getDisplayName();
    if (mounted) {
      setState(() {
        _displayName = name;
        _isLoading = false;
      });
    }
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _displayName ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AtayrColors.background,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AtayrColors.ink, width: 2),
            borderRadius: BorderRadius.circular(0),
          ),
          title: const Text('EDIT DISPLAY NAME', style: TextStyle(fontWeight: FontWeight.bold)),
          content: NeoInput(
            controller: controller,
            label: 'Display Name',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AtayrColors.ink)),
            ),
            NeoButton(
              label: 'SAVE',
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(context);
                  await _updateDisplayName(newName);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDisplayName(String name) async {
    setState(() => _isLoading = true);
    try {
      await _profileService.updateDisplayName(name);
      setState(() {
        _displayName = name;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: AtayrColors.ink),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                    'DISPLAY NAME',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AtayrColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _isLoading ? 'Loading...' : (_displayName ?? 'User'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AtayrColors.ink),
                        onPressed: _isLoading ? null : _showEditNameDialog,
                      ),
                    ],
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
            
            const SizedBox(height: 24),
            
            NeoCard(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FriendsScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FRIENDS & CONNECTIONS',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
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
