import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_section_header.dart';
import '../../core/config/app_config.dart';

class SuggestionResultScreen extends StatelessWidget {
  final Map<String, dynamic> suggestionData;

  const SuggestionResultScreen({
    super.key,
    required this.suggestionData,
  });

  String _getPublicUrl(String path) {
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage.from('wardrobe').getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final storeGarmentImage = suggestionData['store_garment_image_path'];
    final combinations = (suggestionData['combinations'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AtayrColors.background,
      appBar: AppBar(
        backgroundColor: AtayrColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AtayrColors.ink),
        title: Text(
          'OUTFIT SUGGESTIONS',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store Item Header
              const NeoSectionHeader(title: 'YOUR SCANNED ITEM'),
              const SizedBox(height: 16),
              if (storeGarmentImage != null)
                Center(
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      color: AtayrColors.surface,
                      border: Border.all(color: AtayrColors.ink, width: 2),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: _getPublicUrl(storeGarmentImage.replaceAll('.png', '_thumb.webp')),
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: AtayrColors.ink),
                      ),
                      errorWidget: (context, url, error) => CachedNetworkImage(
                        imageUrl: _getPublicUrl(storeGarmentImage),
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              
              if (suggestionData['missing_message'] != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AtayrColors.accent.withOpacity(0.2),
                    border: Border.all(color: AtayrColors.ink, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AtayrColors.ink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          suggestionData['missing_message'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Combinations
              const NeoSectionHeader(title: 'MATCHING OUTFITS FROM WARDROBE'),
              const SizedBox(height: 16),
              
              if (combinations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AtayrColors.surface,
                    border: Border.all(color: AtayrColors.ink, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'No matching outfits could be created from your current wardrobe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              
              ...combinations.map((combo) {
                final outfitImg = combo['outfit_composition_image_path'];
                final styleDirection = combo['style_direction'] ?? 'OUTFIT OPTION';
                final explanation = combo['explanation'] ?? '';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AtayrColors.surface,
                      border: Border.all(color: AtayrColors.ink, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AtayrColors.ink, width: 2)),
                            color: AtayrColors.accent,
                          ),
                          child: Text(
                            styleDirection.toString().toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (outfitImg != null)
                          Container(
                            height: 300,
                            padding: const EdgeInsets.all(16),
                            child: CachedNetworkImage(
                              imageUrl: _getPublicUrl(outfitImg),
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: AtayrColors.ink),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),
                        if (explanation.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AtayrColors.ink, width: 2)),
                              color: Colors.white,
                            ),
                            child: Text(
                              explanation,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 24),
              NeoButton(
                label: 'BACK TO HOME',
                onPressed: () {
                  Navigator.pop(context);
                },
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
