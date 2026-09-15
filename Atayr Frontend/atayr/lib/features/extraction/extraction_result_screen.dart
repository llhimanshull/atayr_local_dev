import 'package:flutter/material.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/widgets/neo_card.dart';
import '../../core/widgets/neo_chip.dart';
import '../wardrobe/wardrobe_service.dart';
import 'models/extraction_models.dart';

class ExtractionResultScreen extends StatelessWidget {
  final GenerationResponse generationResponse;
  final WardrobeService _wardrobeService = WardrobeService();

  ExtractionResultScreen({super.key, required this.generationResponse});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtayrColors.background,
      appBar: AppBar(
        backgroundColor: AtayrColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AtayrColors.ink),
        title: Text(
          'GENERATED ITEMS',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const NeoSectionHeader(title: 'SAVED TO YOUR WARDROBE'),
          const SizedBox(height: 16),
          if (generationResponse.results.isEmpty)
            Text(
              'No items were generated.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          for (var item in generationResponse.results)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: _buildItemCard(context, item),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, GeneratedGarment garment) {
    final meta = garment.metadata;
    final isSuccess = garment.status == 'success';

    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSuccess && garment.imageUrl != null)
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: AtayrColors.ink, width: 2),
                color: AtayrColors.surface,
              ),
              child: Image.network(
                _wardrobeService.getPublicImageUrl(garment.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 48, color: AtayrColors.ink),
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: AtayrColors.ink, width: 2),
                color: AtayrColors.surface,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'FAILED: ${garment.error ?? "Unknown error"}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            meta?.name.toUpperCase() ?? 'UNKNOWN ITEM',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (meta?.category != null) NeoChip(label: meta!.category),
              if (meta?.fit != null) NeoChip(label: meta!.fit),
              if (meta?.primaryColor != null) NeoChip(label: meta!.primaryColor),
            ],
          ),
        ],
      ),
    );
  }
}
