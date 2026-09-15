import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/garment_model.dart';

class GarmentRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all garments for the authenticated user
  Future<List<GarmentModel>> getGarments() async {
    final response = await _client
        .from('garments')
        .select()
        .order('created_at', ascending: false);
    
    return (response as List).map((data) => GarmentModel.fromJson(data)).toList();
  }

  /// Insert a new garment
  Future<GarmentModel> insertGarment(GarmentModel garment) async {
    final response = await _client
        .from('garments')
        .insert(garment.toJson())
        .select()
        .single();
    
    return GarmentModel.fromJson(response);
  }

  /// Update an existing garment
  Future<GarmentModel> updateGarment(GarmentModel garment) async {
    if (garment.id == null) throw Exception("Cannot update garment without an ID");
    
    final response = await _client
        .from('garments')
        .update(garment.toJson())
        .eq('id', garment.id!)
        .select()
        .single();
        
    return GarmentModel.fromJson(response);
  }

  /// Delete a garment
  Future<void> deleteGarment(String id) async {
    await _client.from('garments').delete().eq('id', id);
  }
}
