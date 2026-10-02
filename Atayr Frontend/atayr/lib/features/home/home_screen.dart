import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/widgets/neo_empty_state.dart';
import '../../core/theme/atayr_colors.dart';
import '../wardrobe/wardrobe_service.dart';
import '../wardrobe/models/garment_model.dart';
import '../extraction/jobs_status_screen.dart';
import '../extraction/extraction_service.dart';
import '../extraction/models/processing_job_models.dart';
import '../../services/profile_service.dart';
import '../suggestions/suggestion_service.dart';
import '../suggestions/suggestion_scan_screen.dart';
import '../suggestions/suggestion_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  final ExtractionService _extractionService = ExtractionService();
  final ProfileService _profileService = ProfileService();
  final SuggestionService _suggestionService = SuggestionService();
  
  List<Garment> _recentGarments = [];
  List<ProcessingJobItem> _actionItems = [];
  List<dynamic> _recentSuggestions = [];
  int _totalWardrobeCount = 0;
  String? _displayName;
  int _activeBorrowRequests = 0; // Mocked for now
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    
    try {
      final rawData = await _wardrobeService.getGarments();
      final garments = rawData.map((json) => Garment.fromJson(json)).toList();
      
      final actionItems = await _extractionService.getItemsRequiringAction();
      final suggestions = await _suggestionService.getSuggestionHistory();
      final count = await _wardrobeService.getGarmentCount();
      final name = await _profileService.getDisplayName();
      
      if (mounted) {
        setState(() {
          _recentGarments = garments.take(4).toList();
          _actionItems = actionItems;
          _recentSuggestions = suggestions.take(3).toList();
          _totalWardrobeCount = count;
          _displayName = name;
          _activeBorrowRequests = 0; // Hide borrow requests
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
    final nameToDisplay = _displayName ?? emailPrefix;

    return SafeArea(
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
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
                          _isLoading ? 'HELLO.' : 'HELLO, ${nameToDisplay.toUpperCase()}.',
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
                          ).then((_) => _loadData());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Action Required Banner
                  if (_actionItems.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        // Navigate to PersonSelectionScreen for the first item requiring action
                        Navigator.pushNamed(
                          context, 
                          '/person_selection', 
                          arguments: _actionItems.first,
                        ).then((_) => _loadData());
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          border: Border.all(color: AtayrColors.ink, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: AtayrColors.ink,
                              offset: Offset(4, 4),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ACTION REQUIRED',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_actionItems.length} photo(s) need your attention.',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.touch_app, color: Colors.white, size: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Removed old banner
                  
                  // 3 & 4. Wardrobe count & Recent Scans
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const NeoSectionHeader(title: 'RECENT SCANS'),
                      if (!_isLoading)
                        Text(
                          '$_totalWardrobeCount ITEMS TOTAL',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Wrap the horizontal list in a SizedBox to restrict its height (~60% smaller)
                  SizedBox(
                    height: 140,
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: AtayrColors.ink))
                      : _recentGarments.isEmpty 
                        ? NeoEmptyState(
                            title: 'EMPTY WARDROBE',
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
                                    child: CachedNetworkImage(
                                      imageUrl: _wardrobeService.getPublicImageUrl(
                                          garment.studioImagePath.replaceAll('.png', '_thumb.webp')),
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(color: AtayrColors.ink),
                                      ),
                                      errorWidget: (context, url, error) => CachedNetworkImage(
                                        imageUrl: _wardrobeService.getPublicImageUrl(garment.studioImagePath),
                                        fit: BoxFit.contain,
                                        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Recent borrow requests
                  if (_activeBorrowRequests > 0) ...[
                    const NeoSectionHeader(title: 'RECENT BORROW REQUESTS'),
                    const SizedBox(height: 12),
                    Container(
                      height: 100, // Fixed height instead of Expanded
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
                    const SizedBox(height: 24),
                  ],

                  // 6. Promotion banner
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SuggestionScanScreen()),
                      ).then((_) => _loadData());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      decoration: BoxDecoration(
                        color: AtayrColors.accent,
                        border: Border.all(color: AtayrColors.ink, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: AtayrColors.ink,
                            offset: Offset(4, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'SCAN CLOTHES\nTHAT MATCH\nYOUR WARDROBE',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AtayrColors.ink,
                                  border: Border.all(color: AtayrColors.ink),
                                ),
                                child: const Text(
                                  'SCAN NOW',
                                  style: TextStyle(
                                    color: AtayrColors.background,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Text(
                                '👕 👖 👟',
                                style: TextStyle(fontSize: 24),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 7. Recent AI Suggestions
                  if (_recentSuggestions.isNotEmpty) ...[
                    const NeoSectionHeader(title: 'RECENT AI SUGGESTIONS'),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentSuggestions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final suggestion = _recentSuggestions[index];
                        final storeImg = suggestion['store_garment_image_path'];
                        final combos = suggestion['combinations'] as List<dynamic>? ?? [];
                        final hasCombos = combos.isNotEmpty;
                        
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SuggestionResultScreen(suggestionData: suggestion),
                              ),
                            );
                          },
                          child: Container(
                            height: 100,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AtayrColors.surface,
                              border: Border.all(color: AtayrColors.ink, width: 2),
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                if (storeImg != null)
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AtayrColors.ink, width: 1),
                                      color: Colors.white,
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: _wardrobeService.getPublicImageUrl(
                                          storeImg.replaceAll('.png', '_thumb.webp')),
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(color: AtayrColors.ink),
                                      ),
                                      errorWidget: (context, url, error) => CachedNetworkImage(
                                        imageUrl: _wardrobeService.getPublicImageUrl(storeImg),
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'STORE SCAN',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hasCombos ? '${combos.length} outfit options found' : 'No matches found',
                                        style: TextStyle(color: hasCombos ? AtayrColors.ink : Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Bottom padding for scrollability
                ],
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}
