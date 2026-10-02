import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_chip.dart';
import '../../core/widgets/neo_section_header.dart';
import '../wardrobe/models/garment_model.dart';

class BorrowItemDetailScreen extends StatelessWidget {
  final Garment garment;
  final String ownerName;

  const BorrowItemDetailScreen({
    super.key, 
    required this.garment,
    required this.ownerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtayrColors.background,
      appBar: AppBar(
        backgroundColor: AtayrColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AtayrColors.ink),
        title: Text(
          'BORROW ITEM',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Friend Notice
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AtayrColors.accent.withValues(alpha: 0.2),
              border: Border.all(color: AtayrColors.accent, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.handshake, color: AtayrColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This item belongs to $ownerName and is available to borrow.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Image
          Container(
            height: 400,
            decoration: BoxDecoration(
              border: Border.all(color: AtayrColors.ink, width: 2),
              color: AtayrColors.surface,
            ),
            child: Image.network(
              Supabase.instance.client.storage.from('wardrobe').getPublicUrl(garment.studioImagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, size: 64, color: AtayrColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Name
          Text(
            garment.name.toUpperCase(),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 24),
          
          // Metadata Section
          const NeoSectionHeader(title: 'DETAILS'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              NeoChip(label: 'CAT: ${garment.category.toUpperCase()}'),
              if (garment.subcategory != null) NeoChip(label: 'SUB: ${garment.subcategory!.toUpperCase()}'),
              if (garment.primaryColor != null) NeoChip(label: 'COLOR: ${garment.primaryColor!.toUpperCase()}'),
              if (garment.pattern != null) NeoChip(label: 'PATTERN: ${garment.pattern!.toUpperCase()}'),
              if (garment.style != null) NeoChip(label: 'STYLE: ${garment.style!.toUpperCase()}'),
              if (garment.fit != null) NeoChip(label: 'FIT: ${garment.fit!.toUpperCase()}'),
            ],
          ),
          const SizedBox(height: 48),
          
          // Borrow Action
          NeoButton(
            label: 'REQUEST TO BORROW',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Borrow requests will be available in a future update!'),
                  backgroundColor: AtayrColors.ink,
                ),
              );
            },
            isPrimary: true,
            icon: Icons.send,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
