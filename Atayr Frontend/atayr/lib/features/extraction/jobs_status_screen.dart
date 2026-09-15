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
                                  Text('ITEMS: ${job.totalItems}'),
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
                                // Detailed view of Job Items could go here
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
