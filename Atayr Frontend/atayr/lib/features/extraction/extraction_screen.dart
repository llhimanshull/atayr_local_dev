import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_section_header.dart';
import 'extraction_service.dart';

class ExtractionScreen extends StatefulWidget {
  const ExtractionScreen({super.key});

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

class _ExtractionScreenState extends State<ExtractionScreen> {
  final ImagePicker _picker = ImagePicker();
  final ExtractionService _extractionService = ExtractionService();

  final List<XFile> _selectedImages = [];
  bool _isProcessing = false;
  String _statusText = '';

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      final int maxPhotos = int.tryParse(dotenv.env['MAX_PHOTOS_PER_BATCH'] ?? '10') ?? 10;
      
      if (_selectedImages.length + images.length > maxPhotos) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('MAXIMUM $maxPhotos PHOTOS PER BATCH ALLOWED.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        final int remaining = maxPhotos - _selectedImages.length;
        if (remaining > 0) {
          setState(() {
            _selectedImages.addAll(images.take(remaining));
          });
        }
      } else {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedImages.clear();
    });
  }

  Future<void> _submitBatch() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'SUBMITTING BATCH...';
    });

    try {
      final result = await _extractionService.submitBatch(_selectedImages);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _selectedImages.clear();
      });

      String message = 'BATCH SUBMITTED SUCCESSFULLY!';
      if (result.duplicatesSkipped > 0) {
        if (result.totalSubmitted == result.duplicatesSkipped) {
          message = 'ALL ${result.duplicatesSkipped} PHOTOS WERE DUPLICATES AND SKIPPED.';
        } else {
          message = 'BATCH SUBMITTED! (${result.duplicatesSkipped} DUPLICATES SKIPPED)';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );

      // Return to Dashboard or previous screen where the user can check Jobs
      Navigator.pop(context); 

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ERROR: $e'.toUpperCase()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
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
          'ADD OUTFITS',
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
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        NeoSectionHeader(
          title: _selectedImages.isEmpty 
              ? 'SELECT PHOTOS' 
              : '${_selectedImages.length} PHOTO${_selectedImages.length > 1 ? 'S' : ''} SELECTED'
        ),
        const SizedBox(height: 16),
        
        // Image Selection Grid
        if (_selectedImages.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              // Add more button as the last item
              if (index == _selectedImages.length) {
                return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AtayrColors.surface,
                      border: Border.all(color: AtayrColors.ink, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.add, size: 32, color: AtayrColors.ink),
                    ),
                  ),
                );
              }

              // Display selected image thumbnail
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AtayrColors.ink, width: 2),
                    ),
                    child: Image.file(
                      File(_selectedImages[index].path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cancel, color: Colors.red, size: 24),
                      ),
                      onPressed: () => _removeImage(index),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  label: 'CANCEL',
                  onPressed: _cancelSelection,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NeoButton(
                  label: 'SUBMIT BATCH',
                  onPressed: _submitBatch,
                  isPrimary: true,
                  icon: Icons.upload,
                ),
              ),
            ],
          ),
        ] else ...[
          // Empty state
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: AtayrColors.surface,
                border: Border.all(color: AtayrColors.ink, width: 2),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: AtayrColors.ink),
                    SizedBox(height: 16),
                    Text('TAP TO OPEN GALLERY', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('You can select multiple photos', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
