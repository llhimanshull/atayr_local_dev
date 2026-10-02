import 'package:flutter/material.dart';
import '../../core/theme/atayr_colors.dart';
import 'models/garment_model.dart';
import 'wardrobe_service.dart';
import 'widgets/wardrobe_grid_view.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  
  List<Garment> _allGarments = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadGarments();
  }

  Future<void> _loadGarments() async {
    if (_wardrobeService.hasCachedGarments) {
      if (mounted) {
        setState(() {
          _allGarments = _wardrobeService.getCachedGarments().map((json) => Garment.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = '';
        });
      }
    }
    
    try {
      final rawData = await _wardrobeService.getGarments();
      final garments = rawData.map((json) => Garment.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _allGarments = garments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wardrobe: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        body: WardrobeGridView(
          garments: _allGarments,
          isLoading: _isLoading,
          title: 'WARDROBE',
          emptyStateTitle: 'WARDROBE IS EMPTY',
          emptyStateMessage: 'Your extracted garments will appear here automatically.',
          error: _error,
          onRefresh: _loadGarments,
          readOnly: false,
        ),
      ),
    );
  }
}

