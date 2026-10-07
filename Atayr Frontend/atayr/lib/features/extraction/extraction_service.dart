import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../wardrobe/wardrobe_service.dart';
import 'models/extraction_models.dart';
import 'models/processing_job_models.dart';

class ExtractionException implements Exception {
  final String message;
  ExtractionException(this.message);

  @override
  String toString() => message;
}

class ExtractionService {
  final String baseUrl = AppConfig.apiBaseUrl;
  final WardrobeService _wardrobeService = WardrobeService();
  final Uuid _uuid = const Uuid();
  final SupabaseClient _supabase = Supabase.instance.client;

  MediaType _getMediaType(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png') return MediaType('image', 'png');
    if (ext == 'webp') return MediaType('image', 'webp');
    if (ext == 'heic') return MediaType('image', 'heic');
    if (ext == 'heif') return MediaType('image', 'heif');
    return MediaType('image', 'jpeg');
  }

  Future<String> _getAuthToken() async {
    var session = _supabase.auth.currentSession;
    if (session == null) {
      throw ExtractionException('User is not authenticated');
    }
    if (session.isExpired) {
      try {
        final res = await _supabase.auth.refreshSession();
        if (res.session != null) {
          session = res.session;
        }
      } catch (_) {
        // Ignore and let backend handle 401 if refresh fails
      }
    }
    return session!.accessToken;
  }

  void _handleHttpError(int statusCode, String responseData, String operation) {
    String errorType = 'Unknown error';
    if (statusCode == 401) {
      errorType = 'Authentication/session problem (401)';
    } else if (statusCode == 403) {
      errorType = 'Permission problem (403)';
    } else if (statusCode == 404) {
      errorType = 'Endpoint/configuration problem (404)';
    } else if (statusCode == 408) {
      errorType = 'Request timed out (408)';
    } else if (statusCode >= 500 && statusCode < 600) {
      errorType = 'Backend/server failure ($statusCode)';
    } else {
      errorType = 'Request failed with status: $statusCode';
    }
    throw ExtractionException('$operation failed: $errorType');
  }

  // ============================================================
  // EXISTING SINGLE-IMAGE FLOW (preserved from Step 7)
  // ============================================================

  Future<AnalysisResponse> analyzeImage(XFile image) async {
    final uri = Uri.parse('$baseUrl/analyze-only');
    final token = await _getAuthToken();
    
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'image', 
      image.path,
      contentType: _getMediaType(image.path),
    ));

    try {
      final response = await request.send().timeout(const Duration(seconds: 300));
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        _handleHttpError(response.statusCode, responseData, 'Analysis');
      }

      final jsonMap = jsonDecode(responseData);
      return AnalysisResponse.fromJson(jsonMap);
    } catch (e) {
      if (e is ExtractionException) rethrow;
      if (e is TimeoutException) throw ExtractionException('Analysis timed out');
      throw ExtractionException('Network error during analysis: $e');
    }
  }

  Future<GenerationResponse> generateGarments(XFile image, AnalysisResponse analysisResult) async {
    final uri = Uri.parse('$baseUrl/generate');
    final token = await _getAuthToken();
    
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'image', 
      image.path,
      contentType: _getMediaType(image.path),
    ));
    
    // Convert AnalysisResponse back to JSON string that the backend expects
    // For single flow, we just take the first person's garments
    final itemsList = analysisResult.people.isNotEmpty 
        ? analysisResult.people.first.garments.map((g) => g.toJson()).toList() 
        : [];
        
    final analysisJsonString = jsonEncode({
      'source_image_id': analysisResult.sourceImageId,
      'items': itemsList,
    });
    
    request.fields['analysis_result'] = analysisJsonString;

    GenerationResponse rawResponse;
    try {
      final response = await request.send().timeout(const Duration(seconds: 300));
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        _handleHttpError(response.statusCode, responseData, 'Generation');
      }

      final jsonMap = jsonDecode(responseData);
      rawResponse = GenerationResponse.fromJson(jsonMap);
    } catch (e) {
      if (e is ExtractionException) rethrow;
      if (e is TimeoutException) throw ExtractionException('Generation timed out');
      throw ExtractionException('Network error during generation: $e');
    }

    // --- STEP 6: PERSISTENCE ---
    final userId = _wardrobeService.currentUserId;
    if (userId == null) {
      throw ExtractionException('User not authenticated. Cannot save garments.');
    }

    // Optionally upload source image
    final sourceId = rawResponse.sourceImageId;
    try {
      final sourceBytes = await image.readAsBytes();
      await _wardrobeService.uploadSourceImage(sourceBytes, sourceId);
    } catch (e) {
      // Non-fatal, just continue
      // print('Warning: Could not upload source image: $e');
    }

    final sourceImagePath = '$userId/sources/$sourceId.jpg';
    List<GeneratedGarment> processedGarments = [];

    for (var result in rawResponse.results) {
      if (result.status == 'success' && result.imageBase64 != null && result.metadata != null) {
        try {
          // 1. Decode image bytes from base64
          final imageBytes = base64Decode(result.imageBase64!);

          // 2. Generate Garment UUID
          final garmentId = _uuid.v4();

          // 3. Upload to Supabase Storage
          await _wardrobeService.uploadGarmentImage(imageBytes, garmentId);

          // 4. Insert into Database
          final studioImagePath = '$userId/garments/$garmentId.png';
          final dbRow = {
            'id': garmentId,
            'name': result.metadata!.name,
            'category': result.metadata!.category,
            'subcategory': result.metadata!.subcategory,
            'primary_color': result.metadata!.primaryColor,
            'secondary_color': result.metadata!.secondaryColor,
            'pattern': result.metadata!.pattern,
            'style': result.metadata!.style,
            'fit': result.metadata!.fit,
            'studio_image_path': studioImagePath,
            'source_image_path': sourceImagePath,
          };
          await _wardrobeService.insertGarment(dbRow);

          // 5. Update result with Supabase path instead of python local path
          processedGarments.add(GeneratedGarment(
            itemId: garmentId,
            metadata: result.metadata,
            imageUrl: studioImagePath,
            status: 'success',
          ));

        } catch (e) {
          processedGarments.add(GeneratedGarment(
            itemId: result.itemId,
            metadata: result.metadata,
            status: 'failed',
            error: 'Failed to save to Supabase: $e',
          ));
        }
      } else {
        // Backend generation failed
        processedGarments.add(result);
      }
    }

    return GenerationResponse(
      sourceImageId: rawResponse.sourceImageId,
      results: processedGarments,
    );
  }

  // ============================================================
  // STEP 8: ASYNC JOBS ABSTRACTION
  // ============================================================

  /// Fetch all processing jobs for the current user.
  Future<List<ProcessingJob>> getJobs() async {
    try {
      final response = await _supabase
          .from('processing_jobs')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ProcessingJob.fromJson(json))
          .toList();
    } catch (e) {
      throw ExtractionException('Failed to load processing jobs: $e');
    }
  }

  /// Fetch all items for a specific processing job.
  Future<List<ProcessingJobItem>> getJobItems(String jobId) async {
    try {
      final response = await _supabase
          .from('processing_job_items')
          .select()
          .eq('job_id', jobId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => ProcessingJobItem.fromJson(json))
          .toList();
    } catch (e) {
      throw ExtractionException('Failed to load job items: $e');
    }
  }

  /// Fetch all items requiring user action.
  Future<List<ProcessingJobItem>> getItemsRequiringAction() async {
    final userId = _wardrobeService.currentUserId;
    if (userId == null) return [];
    
    try {
      final response = await _supabase
          .from('processing_job_items')
          .select()
          .eq('user_id', userId)
          .eq('status', 'requires_action')
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => ProcessingJobItem.fromJson(json))
          .toList();
    } catch (e) {
      throw ExtractionException('Failed to load items requiring action: $e');
    }
  }

  /// Create a new job in the database.
  Future<ProcessingJob> createJob(int totalItems) async {
    final userId = _wardrobeService.currentUserId;
    if (userId == null) {
      throw ExtractionException('User not authenticated.');
    }

    final jobId = _uuid.v4();
    try {
      final response = await _supabase.from('processing_jobs').insert({
        'id': jobId,
        'user_id': userId,
        'total_items': totalItems,
      }).select().single();
      
      return ProcessingJob.fromJson(response);
    } catch (e) {
      throw ExtractionException('Failed to create job: $e');
    }
  }

  /// Submit a batch of images for asynchronous processing
  Future<BatchResult> submitBatch(List<XFile> images) async {
    final userId = _wardrobeService.currentUserId;
    if (userId == null) {
      throw ExtractionException('User not authenticated.');
    }

    int duplicatesSkipped = 0;
    List<XFile> uniqueImages = [];
    List<String> uniqueHashes = [];
    Set<String> localHashes = {};

    // 1. Filter duplicates locally and against DB
    for (var image in images) {
      final imageBytes = await image.readAsBytes();
      final digest = sha256.convert(imageBytes);
      final hashStr = digest.toString();

      // Check intra-batch duplicate
      if (localHashes.contains(hashStr)) {
        duplicatesSkipped++;
        continue;
      }
      localHashes.add(hashStr);

      // Check DB duplicate
      try {
        final existing = await _supabase
            .from('source_photos')
            .select()
            .eq('user_id', userId)
            .eq('sha256_hash', hashStr)
            .maybeSingle();
            
        if (existing != null) {
          duplicatesSkipped++;
          continue;
        }
      } catch (e) {
        // Query failed, assume it's new
      }
      
      uniqueImages.add(image);
      uniqueHashes.add(hashStr);
    }

    if (uniqueImages.isEmpty) {
      return BatchResult(
        jobId: null,
        totalSubmitted: images.length,
        duplicatesSkipped: duplicatesSkipped,
      );
    }

    // 2. Create Job
    final job = await createJob(uniqueImages.length);
    final jobId = job.id;

    // 3. Upload images and create job items
    for (int i = 0; i < uniqueImages.length; i++) {
      final image = uniqueImages[i];
      final hashStr = uniqueHashes[i];
      
      final sourceId = _uuid.v4();
      final sourceImagePath = '$userId/sources/$sourceId.jpg';
      final itemId = _uuid.v4();
      
      try {
        final imageBytes = await image.readAsBytes();
        await _wardrobeService.uploadSourceImage(imageBytes, sourceId);
        
        // Save to source_photos to prevent future duplicates
        try {
          await _supabase.from('source_photos').insert({
            'user_id': userId,
            'storage_path': sourceImagePath,
            'sha256_hash': hashStr,
          });
        } catch (e) {
          // It's possible another job inserted it concurrently, ignore duplicate error
        }
        
        await _supabase.from('processing_job_items').insert({
          'id': itemId,
          'job_id': jobId,
          'user_id': userId,
          'source_image_path': sourceImagePath,
          'status': 'queued',
        });
      } catch (e) {
        // If upload fails, create item with failed status
        await _supabase.from('processing_job_items').insert({
          'id': itemId,
          'job_id': jobId,
          'user_id': userId,
          'status': 'failed',
          'error_message': 'Failed to upload source image: $e',
        });
      }
    }

    // 4. Trigger backend background processing
    final uri = Uri.parse('$baseUrl/process-job/$jobId');
    try {
      final token = await _getAuthToken();
      final headers = {'Authorization': 'Bearer $token'};
      final response = await http.post(uri, headers: headers).timeout(const Duration(seconds: 300));
      if (response.statusCode != 200 && response.statusCode != 202) {
        // print('Warning: Backend returned ${response.statusCode} for process-job');
      }
    } catch (e) {
      // print('Warning: Failed to trigger backend processing: $e');
    }

    return BatchResult(
      jobId: jobId,
      totalSubmitted: images.length,
      duplicatesSkipped: duplicatesSkipped,
    );
  }

  /// Resume a paused job item with the selected person
  Future<void> resumeJobItem(String itemId, String personId) async {
    final uri = Uri.parse('$baseUrl/process-job-item/$itemId/resume?person_id=$personId');
    try {
      final token = await _getAuthToken();
      final headers = {'Authorization': 'Bearer $token'};
      final response = await http.post(uri, headers: headers).timeout(const Duration(seconds: 300));
      if (response.statusCode != 200 && response.statusCode != 202) {
        _handleHttpError(response.statusCode, '', 'Resume item');
      }
    } catch (e) {
      if (e is ExtractionException) rethrow;
      if (e is TimeoutException) throw ExtractionException('Resume item timed out');
      throw ExtractionException('Network error during resume: $e');
    }
  }
}
