import 'package:flutter/material.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_chip.dart';
import '../../core/widgets/neo_input.dart';
import '../../core/widgets/neo_section_header.dart';
import 'models/garment_model.dart';
import 'wardrobe_service.dart';

class GarmentDetailScreen extends StatefulWidget {
  final Garment garment;

  const GarmentDetailScreen({super.key, required this.garment});

  @override
  State<GarmentDetailScreen> createState() => _GarmentDetailScreenState();
}

class _GarmentDetailScreenState extends State<GarmentDetailScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  late Garment _garment;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _garment = widget.garment;
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _garment.name);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AtayrColors.background,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AtayrColors.ink, width: 2),
            borderRadius: BorderRadius.circular(0),
          ),
          title: const Text('EDIT NAME', style: TextStyle(fontWeight: FontWeight.bold)),
          content: NeoInput(
            controller: controller,
            label: 'Garment Name',
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
                if (newName.isNotEmpty && newName != _garment.name) {
                  Navigator.pop(context); // Close dialog
                  await _updateName(newName);
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

  Future<void> _updateName(String newName) async {
    setState(() => _isProcessing = true);
    try {
      await _wardrobeService.updateGarmentName(_garment.id, newName);
      setState(() {
        _garment = _garment.copyWith(name: newName);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully'), backgroundColor: AtayrColors.ink),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AtayrColors.background,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AtayrColors.ink, width: 2),
            borderRadius: BorderRadius.circular(0),
          ),
          title: const Text('DELETE GARMENT?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('This action is permanent and cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AtayrColors.ink)),
            ),
            NeoButton(
              label: 'DELETE',
              onPressed: () {
                Navigator.pop(context);
                _deleteGarment();
              },
              isPrimary: false,
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGarment() async {
    setState(() => _isProcessing = true);
    try {
      await _wardrobeService.deleteGarment(_garment.id, _garment.studioImagePath);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
          'ITEM DETAIL',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AtayrColors.ink))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                // Image
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: AtayrColors.ink, width: 2),
                    color: AtayrColors.surface,
                  ),
                  child: Image.network(
                    _wardrobeService.getPublicImageUrl(_garment.studioImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, size: 64, color: AtayrColors.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Name & Edit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _garment.name.toUpperCase(),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AtayrColors.ink),
                      onPressed: _showEditNameDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Metadata Section
                const NeoSectionHeader(title: 'METADATA'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    NeoChip(label: 'CAT: ${_garment.category.toUpperCase()}'),
                    NeoChip(label: 'SUB: ${_garment.subcategory.toUpperCase()}'),
                    if (_garment.primaryColor != null)
                      NeoChip(label: 'COLOR: ${_garment.primaryColor!.toUpperCase()}'),
                    if (_garment.secondaryColor != null)
                      NeoChip(label: 'SEC: ${_garment.secondaryColor!.toUpperCase()}'),
                    NeoChip(label: 'PATTERN: ${_garment.pattern.toUpperCase()}'),
                    NeoChip(label: 'STYLE: ${_garment.style.toUpperCase()}'),
                    NeoChip(label: 'FIT: ${_garment.fit.toUpperCase()}'),
                  ],
                ),
                const SizedBox(height: 48),
                
                // Delete
                NeoButton(
                  label: 'DELETE GARMENT',
                  onPressed: _confirmDelete,
                  isPrimary: false,
                  icon: Icons.delete_outline,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
