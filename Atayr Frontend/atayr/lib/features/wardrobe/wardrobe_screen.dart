import 'package:flutter/material.dart';
import '../../core/widgets/neo_empty_state.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/widgets/neo_input.dart';
import '../../core/theme/atayr_colors.dart';
import 'models/garment_model.dart';
import 'wardrobe_service.dart';
import 'garment_detail_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Garment> _allGarments = [];
  List<Garment> _filteredGarments = [];
  bool _isLoading = true;
  String _error = '';
  
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Upper', 'Lower', 'Outerwear', 'Footwear', 'Accessories'];

  @override
  void initState() {
    super.initState();
    _loadGarments();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGarments() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final rawData = await _wardrobeService.getGarments();
      final garments = rawData.map((json) => Garment.fromJson(json)).toList();
      setState(() {
        _allGarments = garments;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredGarments = _allGarments.where((garment) {
        // Search
        final matchesSearch = garment.name.toLowerCase().contains(query);
        
        // Category Filter
        bool matchesCategory = true;
        if (_selectedFilter != 'All') {
          String canonicalFilter = _selectedFilter.toLowerCase();
          if (canonicalFilter == 'accessories') canonicalFilter = 'accessory';
          
          matchesCategory = garment.category.toLowerCase() == canonicalFilter;
        }
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _onFilterTapped(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NeoSectionHeader(title: 'WARDROBE'),
                  const SizedBox(height: 16),
                  NeoInput(
                    controller: _searchController,
                    label: 'SEARCH ITEMS',
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = filter == _selectedFilter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => _onFilterTapped(filter),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AtayrColors.accent : AtayrColors.background,
                                border: Border.all(color: AtayrColors.ink, width: 2),
                              ),
                              child: Text(
                                filter.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AtayrColors.ink),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AtayrColors.ink));
    }
    
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading wardrobe:\n$_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    
    if (_allGarments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: NeoEmptyState(
          title: 'WARDROBE IS EMPTY',
          message: 'Your extracted garments will appear here automatically.',
          ctaLabel: 'REFRESH',
          onCtaPressed: _loadGarments,
        ),
      );
    }

    if (_filteredGarments.isEmpty) {
      return const Center(
        child: Text('No garments match your filters.', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.70, // Slightly taller to fit image + text nicely
      ),
      itemCount: _filteredGarments.length,
      itemBuilder: (context, index) {
        final garment = _filteredGarments[index];
        return _buildGarmentCard(garment);
      },
    );
  }

  Widget _buildGarmentCard(Garment garment) {
    return GestureDetector(
      onTap: () async {
        final didDelete = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GarmentDetailScreen(garment: garment),
          ),
        );
        // If we deleted a garment or modified it, reload
        if (didDelete == true) {
          _loadGarments();
        } else {
          // It might have been renamed, so a reload is safe anyway.
          // In a real app we might just update the local item, but reloading is clean.
          _loadGarments();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AtayrColors.surface,
          border: Border.all(color: AtayrColors.ink, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.network(
                  _wardrobeService.getPublicImageUrl(garment.studioImagePath),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, color: AtayrColors.ink),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AtayrColors.ink, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garment.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    garment.category.toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
