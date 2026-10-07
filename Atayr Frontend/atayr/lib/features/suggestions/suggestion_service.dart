import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../extraction/models/extraction_models.dart';

class SuggestionService {
  final String baseUrl = AppConfig.apiBaseUrl;
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
      throw Exception('User is not authenticated');
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
    throw Exception('$operation failed: $errorType');
  }

  Future<Map<String, dynamic>> generateSuggestion(XFile image, ExtractedItem selectedGarment) async {
    final uri = Uri.parse('$baseUrl/generate-suggestion');
    final token = await _getAuthToken();
    
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    
    request.files.add(await http.MultipartFile.fromPath(
      'image', 
      image.path,
      contentType: _getMediaType(image.path),
    ));
    
    request.fields['item_json'] = jsonEncode(selectedGarment.toJson());

    try {
      final response = await request.send().timeout(const Duration(seconds: 300));
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        _handleHttpError(response.statusCode, responseData, 'Suggestion generation');
      }

      return jsonDecode(responseData);
    } catch (e) {
      if (e is TimeoutException) throw Exception('Suggestion generation timed out');
      throw Exception('Network error during suggestion generation: $e');
    }
  }

  Future<List<dynamic>> getSuggestionHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    
    final historyPath = '$userId/suggestions_history.json';
    try {
      final response = await _supabase.storage.from('wardrobe').download(historyPath);
      final String jsonStr = utf8.decode(response);
      return jsonDecode(jsonStr) as List<dynamic>;
    } catch (e) {
      // File probably doesn't exist yet
      return [];
    }
  }
}
