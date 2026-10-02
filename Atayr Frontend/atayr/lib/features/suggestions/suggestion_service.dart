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

  Future<Map<String, dynamic>> generateSuggestion(XFile image, ExtractedItem selectedGarment) async {
    final uri = Uri.parse('$baseUrl/generate-suggestion');
    final token = _supabase.auth.currentSession?.accessToken;
    
    var request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    request.files.add(await http.MultipartFile.fromPath(
      'image', 
      image.path,
      contentType: _getMediaType(image.path),
    ));
    
    request.fields['item_json'] = jsonEncode(selectedGarment.toJson());

    try {
      final response = await request.send().timeout(const Duration(minutes: 5));
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        throw Exception('Suggestion generation failed: ${response.statusCode} - $responseData');
      }

      return jsonDecode(responseData);
    } catch (e) {
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
