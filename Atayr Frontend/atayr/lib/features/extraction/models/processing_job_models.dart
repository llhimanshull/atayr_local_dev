// Models for asynchronous processing jobs and items.
// Maps to the `processing_jobs` and `processing_job_items` Supabase tables.

class ProcessingJob {
  final String id;
  final String userId;
  final String status;
  final int totalItems;
  final int completedItems;
  final int failedItems;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProcessingJob({
    required this.id,
    required this.userId,
    required this.status,
    this.totalItems = 0,
    this.completedItems = 0,
    this.failedItems = 0,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProcessingJob.fromJson(Map<String, dynamic> json) {
    return ProcessingJob(
      id: json['id'],
      userId: json['user_id'],
      status: json['status'] ?? 'queued',
      totalItems: json['total_items'] ?? 0,
      completedItems: json['completed_items'] ?? 0,
      failedItems: json['failed_items'] ?? 0,
      errorMessage: json['error_message'],
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'status': status,
    'total_items': totalItems,
    'completed_items': completedItems,
    'failed_items': failedItems,
    'error_message': errorMessage,
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class ProcessingJobItem {
  final String id;
  final String jobId;
  final String userId;
  final String? sourceImagePath;
  final String status;
  final String? errorMessage;
  final double progress;
  final Map<String, dynamic>? analysisData;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProcessingJobItem({
    required this.id,
    required this.jobId,
    required this.userId,
    this.sourceImagePath,
    required this.status,
    this.errorMessage,
    required this.progress,
    this.analysisData,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProcessingJobItem.fromJson(Map<String, dynamic> json) {
    return ProcessingJobItem(
      id: json['id'],
      jobId: json['job_id'],
      userId: json['user_id'],
      sourceImagePath: json['source_image_path'],
      status: json['status'] ?? 'queued',
      errorMessage: json['error_message'],
      progress: (json['progress'] ?? 0.0).toDouble(),
      analysisData: json['analysis_data'],
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'job_id': jobId,
    'user_id': userId,
    'source_image_path': sourceImagePath,
    'status': status,
    'error_message': errorMessage,
    'progress': progress,
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
