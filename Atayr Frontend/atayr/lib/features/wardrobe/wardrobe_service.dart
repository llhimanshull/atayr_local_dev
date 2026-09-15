import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class WardrobeException implements Exception {
  final String message;
  WardrobeException(this.message);
  @override
  String toString() => message;
}

class WardrobeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<void> uploadGarmentImage(Uint8List imageBytes, String garmentId) async {
    final userId = currentUserId;
    if (userId == null) throw WardrobeException('User not authenticated.');

    final path = '$userId/garments/$garmentId.png';
    
    try {
      await _supabase.storage.from('wardrobe').uploadBinary(
        path, 
        imageBytes, 
        fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
      );
    } catch (e) {
      throw WardrobeException('Failed to upload garment image: $e');
    }
  }

  Future<void> uploadSourceImage(Uint8List imageBytes, String sourceId) async {
    final userId = currentUserId;
    if (userId == null) throw WardrobeException('User not authenticated.');

    final path = '$userId/sources/$sourceId.jpg';
    
    try {
      await _supabase.storage.from('wardrobe').uploadBinary(
        path, 
        imageBytes, 
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
    } catch (e) {
      throw WardrobeException('Failed to upload source image: $e');
    }
  }

  Future<void> insertGarment(Map<String, dynamic> garmentData) async {
    final userId = currentUserId;
    if (userId == null) throw WardrobeException('User not authenticated.');

    // Ensure user_id is injected securely
    final dataToInsert = Map<String, dynamic>.from(garmentData);
    dataToInsert['user_id'] = userId;

    try {
      await _supabase.from('garments').insert(dataToInsert);
    } catch (e) {
      throw WardrobeException('Failed to insert garment record: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getGarments() async {
    try {
      final response = await _supabase
          .from('garments')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw WardrobeException('Failed to load garments: $e');
    }
  }

  Future<void> updateGarmentName(String id, String newName) async {
    try {
      await _supabase
          .from('garments')
          .update({'name': newName})
          .eq('id', id);
    } catch (e) {
      throw WardrobeException('Failed to update garment name: $e');
    }
  }

  Future<void> deleteGarment(String id, String studioImagePath) async {
    try {
      // 1. Delete from database
      await _supabase.from('garments').delete().eq('id', id);
      
      // 2. Delete the image from storage to prevent orphaned files
      await _supabase.storage.from('wardrobe').remove([studioImagePath]);
    } catch (e) {
      throw WardrobeException('Failed to delete garment: $e');
    }
  }

  String getPublicImageUrl(String path) {
    return _supabase.storage.from('wardrobe').getPublicUrl(path);
  }
}
