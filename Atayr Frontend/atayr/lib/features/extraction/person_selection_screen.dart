import 'package:flutter/material.dart';
import '../../core/theme/atayr_colors.dart';
import '../wardrobe/wardrobe_service.dart';
import 'extraction_service.dart';
import 'models/extraction_models.dart';
import 'models/processing_job_models.dart';

class PersonSelectionScreen extends StatefulWidget {
  final ProcessingJobItem item;

  const PersonSelectionScreen({super.key, required this.item});

  @override
  State<PersonSelectionScreen> createState() => _PersonSelectionScreenState();
}

class _PersonSelectionScreenState extends State<PersonSelectionScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  final ExtractionService _extractionService = ExtractionService();
  
  List<Person> _people = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _parseAnalysisData();
  }

  void _parseAnalysisData() {
    if (widget.item.analysisData != null) {
      final response = AnalysisResponse.fromJson(widget.item.analysisData!);
      setState(() {
        _people = response.people;
      });
    }
  }

  Future<void> _selectPerson(Person person) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _extractionService.resumeJobItem(widget.item.id, person.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SELECTION SAVED. RESUMING JOB...'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.sourceImagePath == null || _people.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ERROR')),
        body: const Center(child: Text('Invalid data for person selection.')),
      );
    }

    final imageUrl = _wardrobeService.getPublicImageUrl(widget.item.sourceImagePath!);

    return Scaffold(
      backgroundColor: AtayrColors.background,
      appBar: AppBar(
        backgroundColor: AtayrColors.background,
        iconTheme: const IconThemeData(color: AtayrColors.ink),
        title: Text('WHICH ONE IS YOU?', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Multiple people were detected in this photo. Please tap your person card below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            // Context View (Top)
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: AtayrColors.ink, width: 2),
                  color: AtayrColors.surface,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: AtayrColors.ink));
                  },
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Selection View (Bottom)
            Expanded(
              flex: 3,
              child: _isSubmitting 
                ? const Center(child: CircularProgressIndicator(color: AtayrColors.ink))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _people.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final person = _people[index];
                      return _buildPersonCard(person, index + 1, imageUrl);
                    },
                  ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard(Person person, int index, String imageUrl) {
    final box = person.boundingBox;
    
    // Calculate the width and height as fractions of the original image
    final widthFrac = box.xMax - box.xMin;
    final heightFrac = box.yMax - box.yMin;
    
    return GestureDetector(
      onTap: () => _selectPerson(person),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AtayrColors.surface,
          border: Border.all(color: AtayrColors.ink, width: 2),
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
            Container(
              color: AtayrColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'PERSON $index',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AtayrColors.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 1, 
                    height: 1,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -box.xMin * (1 / widthFrac),
                          top: -box.yMin * (1 / heightFrac),
                          width: 1 / widthFrac,
                          height: 1 / heightFrac,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
