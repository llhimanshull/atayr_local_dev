import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friendship_model.dart';
import '../models/friend_with_profile.dart';

class FriendService {
  final SupabaseClient _client = Supabase.instance.client;
  final Random _random = Random();

  /// Generate or retrieve an invite code for the current user
  Future<String> getOrCreateInviteCode() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final existing = await _client
        .from('friend_invites')
        .select('invite_code')
        .eq('inviter_id', userId)
        .gte('expires_at', DateTime.now().toUtc().toIso8601String())
        .maybeSingle();

    if (existing != null) {
      return existing['invite_code'] as String;
    }

    final code = _generateRandomCode(6);
    await _client.from('friend_invites').insert({
      'inviter_id': userId,
      'invite_code': code,
    });

    return code;
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Use an invite code
  Future<void> useInviteCode(String code) async {
    await _client.rpc('use_invite_code', params: {'code': code.toUpperCase()});
  }

  /// Get pending requests (where current user is the recipient: user_b_id)
  Future<List<FriendshipModel>> getPendingRequests() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('friendships')
        .select()
        .eq('user_b_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List).map((data) => FriendshipModel.fromJson(data)).toList();
  }

  /// Get accepted friends
  Future<List<FriendshipModel>> getFriends() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('friendships')
        .select()
        .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    return (response as List).map((data) => FriendshipModel.fromJson(data)).toList();
  }

  /// Get accepted friends with profile information
  Future<List<FriendWithProfile>> getFriendsWithProfiles() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // 1. Fetch accepted friendships
    final response = await _client
        .from('friendships')
        .select()
        .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    if ((response as List).isEmpty) return [];

    final List<FriendWithProfile> friends = [];

    // 2. Process each friend and fetch profile + garment count
    for (final data in response) {
      final String userAId = data['user_a_id'] as String;
      final String userBId = data['user_b_id'] as String;
      final friendUserId = userAId == userId ? userBId : userAId;

      String displayName = 'User';
      int sharedCount = 0;

      try {
        // Fetch profile
        final profileResponse = await _client
            .from('profiles')
            .select('display_name')
            .eq('id', friendUserId)
            .maybeSingle();
            
        if (profileResponse != null) {
          displayName = profileResponse['display_name'] as String? ?? 'User';
        }

        // Fetch shared garment count
        final garments = await _client
            .from('garments')
            .select('id')
            .eq('user_id', friendUserId);
            
        sharedCount = (garments as List).length;
      } catch (e) {
        // Ignore individual fetch errors, fall back to defaults
      }

      data['friend_display_name'] = displayName;
      data['shared_item_count'] = sharedCount;

      friends.add(FriendWithProfile.fromJson(data, userId));
    }

    return friends;
  }

  /// Remove a friendship
  Future<void> removeFriend(String friendshipId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    
    // RLS ensures they can only delete if they are part of the friendship
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  /// Accept a request
  Future<void> acceptRequest(String requestId) async {
    await _client.rpc('accept_friend_request', params: {'request_id': requestId});
  }

  /// Decline a request
  Future<void> declineRequest(String requestId) async {
    await _client.rpc('decline_friend_request', params: {'request_id': requestId});
  }
}
