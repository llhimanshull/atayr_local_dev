import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/widgets/neo_empty_state.dart';
import '../../core/theme/atayr_colors.dart';
import '../wardrobe/wardrobe_service.dart';
import '../wardrobe/models/garment_model.dart';
import '../extraction/jobs_status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  List<Garment> _recentGarments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final rawData = await _wardrobeService.getGarments();
      final garments = rawData.map((json) => Garment.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _recentGarments = garments.take(4).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final emailPrefix = user?.email?.split('@').first ?? 'FASHIONISTA';

    return SafeArea(
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'HELLO, ${emailPrefix.toUpperCase()}.',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            letterSpacing: -1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history, color: AtayrColors.ink, size: 32),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const JobsStatusScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 2. Scan clothes that match your wardrobe (Placeholder)
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Buy Smart AI coming soon...')),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AtayrColors.accent,
                        border: Border.all(color: AtayrColors.ink, width: 2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'SCAN CLOTHES THAT MATCH YOUR WARDROBE',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.arrow_forward, color: AtayrColors.ink),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 3 & 4. Wardrobe count & Recent Wardrobe
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const NeoSectionHeader(title: 'RECENT WARDROBE'),
                      if (!_isLoading && _recentGarments.isNotEmpty)
                        Text(
                          '${_recentGarments.length} ITEMS', // Optionally show total length if we didn't slice it to 4, but this is fine
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Expanded(
                    flex: 3,
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: AtayrColors.ink))
                      : _recentGarments.isEmpty 
                        ? NeoEmptyState(
                            title: 'NO RECENT ITEMS',
                            message: 'Extract an outfit to start building your wardrobe.',
                            ctaLabel: 'REFRESH',
                            onCtaPressed: _loadData,
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentGarments.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final garment = _recentGarments[index];
                              return AspectRatio(
                                aspectRatio: 0.75,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AtayrColors.surface,
                                    border: Border.all(color: AtayrColors.ink, width: 2),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.network(
                                      _wardrobeService.getPublicImageUrl(garment.studioImagePath),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Recent borrow requests
                  const NeoSectionHeader(title: 'RECENT BORROW REQUESTS'),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AtayrColors.ink, width: 2),
                        color: AtayrColors.surface,
                      ),
                      child: const Center(
                        child: Text(
                          'NO ACTIVE REQUESTS',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Promotion banner
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AtayrColors.ink, width: 2),
                      color: AtayrColors.ink,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Center(
                      child: Text(
                        'BUY LESS. BORROW MORE.',
                        style: TextStyle(
                          color: AtayrColors.background,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
