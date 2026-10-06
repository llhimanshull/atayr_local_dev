import 'package:flutter/material.dart';
import '../../core/theme/atayr_colors.dart';
import 'extraction_service.dart';
import 'models/processing_job_models.dart';
import 'package:intl/intl.dart';

class JobsStatusScreen extends StatefulWidget {
  const JobsStatusScreen({super.key});

  @override
  State<JobsStatusScreen> createState() => _JobsStatusScreenState();
}

class _JobsStatusScreenState extends State<JobsStatusScreen> {
  final ExtractionService _extractionService = ExtractionService();
  List<ProcessingJob> _jobs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await _extractionService.getJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy - h:mm a').format(date.toLocal());
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'processing':
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
        );
      case 'queued':
        return const Icon(Icons.schedule, color: Colors.orange);
      case 'requires_action':
        return const Icon(Icons.touch_app, color: Colors.deepOrange);
      case 'skipped':
        return const Icon(Icons.do_not_disturb_alt, color: Colors.deepOrange);
      case 'failed':
      case 'cancelled':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.help_outline);
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
          'BATCH JOBS',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadJobs();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AtayrColors.ink))
            : _error != null
                ? Center(
                    child: Text(
                      'ERROR: $_error',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  )
                : _jobs.isEmpty
                    ? const Center(
                        child: Text(
                          'NO BATCH JOBS FOUND',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _jobs.length,
                        itemBuilder: (context, index) {
                          final job = _jobs[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                'JOB: ${job.id.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text('DATE: ${_formatDate(job.createdAt)}'),
                                  Text('PROCESSED: ${job.completedItems}'),
                                  Text('SKIPPED/FAILED: ${job.failedItems}'),
                                  if (job.errorMessage != null)
                                    Text('ERROR: ${job.errorMessage}', style: const TextStyle(color: Colors.red)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildStatusIcon(job.status),
                                  const SizedBox(height: 4),
                                  Text(
                                    job.status.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showJobItems(job.id);
                              },
                            ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  void _showJobItems(String jobId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AtayrColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('JOB ITEMS', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<ProcessingJobItem>>(
                  future: _extractionService.getJobItems(jobId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AtayrColors.ink));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(child: Text('No items found.'));
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSkipped = item.status == 'skipped';
                        
                        return Card(
                          color: AtayrColors.background,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: AtayrColors.ink, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                            leading: _buildStatusIcon(item.status),
                            title: Text('ITEM ${index + 1} - ${item.status.toUpperCase()}'),
                            subtitle: isSkipped
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      const Text('Multiple people detected.', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      const Text('Atayr currently works with photos containing one person. Please upload a photo where you\'re alone.', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AtayrColors.ink, foregroundColor: Colors.white),
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Choose another photo', style: TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Skip', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Text('Progress: ${(item.progress * 100).toInt()}%'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
