import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> getDisplayName() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      
      String? name;
      if (response != null && response['display_name'] != null && response['display_name'].toString().trim().isNotEmpty) {
        name = response['display_name'] as String;
      }
      
      if (name == null || name == 'User' || name == 'Unknown' || name == user.id) {
        final meta = user.userMetadata;
        if (meta != null) {
          name = meta['full_name'] as String? ?? meta['name'] as String?;
        }
      }
      
      return name;
    } catch (e) {
      // Fallback on error
      final meta = user.userMetadata;
      if (meta != null) {
        return meta['full_name'] as String? ?? meta['name'] as String?;
      }
      return null;
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final userId = _client.auth.currentUser!.id;
    try {
      // Use upsert to handle cases where profile doesn't exist yet
      await _client.from('profiles').upsert({
        'id': userId,
        'display_name': displayName,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update display name: $e');
    }
  }
}
