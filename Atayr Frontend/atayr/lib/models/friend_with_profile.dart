class FriendWithProfile {
  final String friendshipId;
  final String friendUserId;
  final String displayName;
  final int sharedItemCount;
  final DateTime friendsSince;

  FriendWithProfile({
    required this.friendshipId,
    required this.friendUserId,
    required this.displayName,
    this.sharedItemCount = 0,
    required this.friendsSince,
  });

  factory FriendWithProfile.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Determine the friend's ID based on which one the current user is NOT
    final String userAId = json['user_a_id'] as String;
    final String userBId = json['user_b_id'] as String;
    final friendUserId = userAId == currentUserId ? userBId : userAId;

    return FriendWithProfile(
      friendshipId: json['id'] as String,
      friendUserId: friendUserId,
      displayName: json['friend_display_name'] as String? ?? 'Unknown',
      sharedItemCount: json['shared_item_count'] as int? ?? 0,
      friendsSince: DateTime.parse(json['created_at'] as String),
    );
  }
}
