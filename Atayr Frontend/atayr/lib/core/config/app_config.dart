import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static bool _isInitialized = false;

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
      _isInitialized = true;
    } catch (e) {
      // Ignore if .env is missing
    }
  }

  static String get supabaseUrl => _isInitialized ? (dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co') : 'https://placeholder.supabase.co';
  static String get supabaseAnonKey => _isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholder-key') : 'placeholder-key';
  static String get apiBaseUrl => _isInitialized ? (dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000') : 'http://localhost:8000';
}
