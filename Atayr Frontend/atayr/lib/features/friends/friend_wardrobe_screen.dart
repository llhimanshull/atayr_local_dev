import 'package:flutter/material.dart';
import '../../core/theme/atayr_colors.dart';
import '../../models/friend_with_profile.dart';
import '../wardrobe/models/garment_model.dart';
import '../wardrobe/wardrobe_service.dart';
import '../wardrobe/widgets/wardrobe_grid_view.dart';

class FriendWardrobeScreen extends StatefulWidget {
  final FriendWithProfile friend;

  const FriendWardrobeScreen({super.key, required this.friend});

  @override
  State<FriendWardrobeScreen> createState() => _FriendWardrobeScreenState();
}

class _FriendWardrobeScreenState extends State<FriendWardrobeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  bool _isLoading = true;
  String? _error;
  List<Garment> _garments = [];

  @override
  void initState() {
    super.initState();
    _loadGarments();
  }

  Future<void> _loadGarments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final rawData = await _wardrobeService.getFriendGarments(widget.friend.friendUserId);
      setState(() {
        _garments = rawData.map((data) => Garment.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtayrColors.background,
      appBar: AppBar(
        backgroundColor: AtayrColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AtayrColors.ink),
      ),
      body: WardrobeGridView(
        garments: _garments,
        isLoading: _isLoading,
        title: '${widget.friend.displayName.toUpperCase()}\'S WARDROBE',
        emptyStateTitle: 'EMPTY WARDROBE',
        emptyStateMessage: '${widget.friend.displayName} hasn\'t added any garments yet.',
        error: _error,
        onRefresh: _loadGarments,
        readOnly: true,
        ownerName: widget.friend.displayName,
      ),
    );
  }
}

