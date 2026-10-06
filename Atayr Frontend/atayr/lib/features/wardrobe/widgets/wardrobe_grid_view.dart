import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/neo_empty_state.dart';
import '../../../core/widgets/neo_section_header.dart';
import '../../../core/widgets/neo_input.dart';
import '../../../core/theme/atayr_colors.dart';
import '../models/garment_model.dart';
import '../wardrobe_service.dart';
import '../garment_detail_screen.dart';

class WardrobeGridView extends StatefulWidget {
  final List<Garment> garments;
  final bool isLoading;
  final String title;
  final String emptyStateTitle;
  final String emptyStateMessage;
  final String? error;
  final Future<void> Function() onRefresh;
  final bool readOnly;
  final String? ownerName;

  const WardrobeGridView({
    super.key,
    required this.garments,
    required this.isLoading,
    required this.title,
    required this.emptyStateTitle,
    required this.emptyStateMessage,
    required this.onRefresh,
    this.error,
    this.readOnly = false,
    this.ownerName,
  });

  @override
  State<WardrobeGridView> createState() => _WardrobeGridViewState();
}

class _WardrobeGridViewState extends State<WardrobeGridView> {
  final WardrobeService _wardrobeService = WardrobeService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Garment> _filteredGarments = [];
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Top', 'Bottom', 'Outerwear', 'Footwear', 'Accessories'];

  @override
  void initState() {
    super.initState();
    _filteredGarments = widget.garments;
    _searchController.addListener(_applyFilters);
  }

  @override
  void didUpdateWidget(WardrobeGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.garments != widget.garments) {
      _applyFilters();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredGarments = widget.garments.where((garment) {
        // Search
        final matchesSearch = garment.name.toLowerCase().contains(query);
        
        // Category Filter
        bool matchesCategory = true;
        if (_selectedFilter != 'All') {
          matchesCategory = garment.canonicalCategory == _selectedFilter;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeoSectionHeader(title: widget.title),
              const SizedBox(height: 8),
              if (!widget.readOnly)
                Text(
                  '${widget.garments.length} / 30 WARDROBE ITEMS',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                ),
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
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AtayrColors.ink));
    }
    
    if (widget.error != null && widget.error!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading wardrobe:\n${widget.error}', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    
    if (widget.garments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: NeoEmptyState(
          title: widget.emptyStateTitle,
          message: widget.emptyStateMessage,
          ctaLabel: 'REFRESH',
          onCtaPressed: widget.onRefresh,
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
        childAspectRatio: 0.70,
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
            builder: (context) => GarmentDetailScreen(
              garment: garment,
              readOnly: widget.readOnly,
              ownerName: widget.ownerName,
            ),
          ),
        );
        // If we deleted a garment or modified it, reload
        if (didDelete == true || !widget.readOnly) {
          widget.onRefresh();
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
                child: CachedNetworkImage(
                  imageUrl: _wardrobeService.getPublicImageUrl(
                      garment.studioImagePath.replaceAll('.png', '_thumb.webp')
                  ),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: AtayrColors.ink),
                  ),
                  errorWidget: (context, url, error) => CachedNetworkImage(
                    // Fallback to original if thumb doesn't exist yet (Migration Strategy)
                    imageUrl: _wardrobeService.getPublicImageUrl(garment.studioImagePath),
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, color: AtayrColors.ink),
                    ),
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
                    garment.canonicalCategory.toUpperCase(),
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
