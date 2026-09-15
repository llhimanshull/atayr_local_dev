import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class ApiService {
  final http.Client _client = http.Client();

  Future<http.Response> analyzeImage(String imagePath) async {
    // This will be implemented to send image to Python backend
    final url = Uri.parse('${AppConfig.apiBaseUrl}/analyze');
    // Implementation placeholder
    return _client.post(url);
  }

  Future<http.Response> generateImage(Map<String, dynamic> data) async {
    // This will be implemented to generate images via Python backend
    final url = Uri.parse('${AppConfig.apiBaseUrl}/generate');
    // Implementation placeholder
    return _client.post(url);
  }
}
