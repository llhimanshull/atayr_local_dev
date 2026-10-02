import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_section_header.dart';
import '../extraction/extraction_service.dart';
import '../extraction/models/extraction_models.dart';
import 'suggestion_service.dart';
import 'suggestion_result_screen.dart';

class SuggestionScanScreen extends StatefulWidget {
  const SuggestionScanScreen({super.key});

  @override
  State<SuggestionScanScreen> createState() => _SuggestionScanScreenState();
}

class _SuggestionScanScreenState extends State<SuggestionScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final ExtractionService _extractionService = ExtractionService();
  final SuggestionService _suggestionService = SuggestionService();

  XFile? _selectedImage;
  bool _isProcessing = false;
  String _statusText = '';
  
  AnalysisResponse? _analysisResult;
  ExtractedItem? _selectedGarment;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _analysisResult = null;
        _selectedGarment = null;
      });
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'ANALYZING PHOTO...';
    });

    try {
      final result = await _extractionService.analyzeImage(_selectedImage!);
      
      if (!mounted) return;
      
      setState(() {
        _analysisResult = result;
        _isProcessing = false;
        
        // If there's only one person and one garment, auto-select it
        if (result.people.length == 1 && result.people.first.garments.length == 1) {
          _selectedGarment = result.people.first.garments.first;
          _generateSuggestion();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e'.toUpperCase()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generateSuggestion() async {
    if (_selectedImage == null || _selectedGarment == null) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'GENERATING OUTFITS...';
    });

    try {
      final result = await _suggestionService.generateSuggestion(_selectedImage!, _selectedGarment!);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        // Navigate to result screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SuggestionResultScreen(
              suggestionData: result['suggestion'],
            ),
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Failed to generate outfits');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e'.toUpperCase()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtayrColors.background,
      appBar: AppBar(
        backgroundColor: AtayrColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AtayrColors.ink),
        title: Text(
          'AI SUGGESTIONS',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: _isProcessing 
            ? _buildProcessingState() 
            : _buildSelectionState(),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AtayrColors.ink, strokeWidth: 4),
          const SizedBox(height: 32),
          Text(
            _statusText,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionState() {
    if (_selectedImage == null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_awesome, size: 80, color: AtayrColors.ink),
            const SizedBox(height: 24),
            Text(
              'SCAN A GARMENT IN STORE',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'See how it matches with clothes you already own before you buy.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            NeoButton(
              label: 'TAKE PHOTO',
              onPressed: () => _pickImage(ImageSource.camera),
              isPrimary: true,
              icon: Icons.camera_alt,
            ),
            const SizedBox(height: 16),
            NeoButton(
              label: 'CHOOSE FROM GALLERY',
              onPressed: () => _pickImage(ImageSource.gallery),
              isPrimary: false,
              icon: Icons.photo_library,
            ),
          ],
        ),
      );
    }

    // Showing analysis results (Garment Selection)
    if (_analysisResult != null) {
      final allGarments = _analysisResult!.people.expand((p) => p.garments).toList();
      
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NeoSectionHeader(title: 'WHICH GARMENT?'),
            const SizedBox(height: 16),
            const Text(
              'We found a few items in this photo (like your t-shirt and specs). Tap the one you want to find matching outfits for.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Selected Image Preview
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: AtayrColors.ink, width: 2),
                image: DecorationImage(
                  image: FileImage(File(_selectedImage!.path)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Garment List
            ...allGarments.map((g) {
              final isSelected = _selectedGarment?.id == g.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGarment = g;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AtayrColors.ink : AtayrColors.surface,
                      border: Border.all(color: AtayrColors.ink, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${g.category.toUpperCase()} (${g.primaryColor.toUpperCase()})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AtayrColors.ink,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 32),
            NeoButton(
              label: 'GENERATE OUTFITS',
              onPressed: _selectedGarment != null ? () { _generateSuggestion(); } : () {},
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            NeoButton(
              label: 'TRY DIFFERENT PHOTO',
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _analysisResult = null;
                  _selectedGarment = null;
                });
              },
              isPrimary: false,
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }
}
