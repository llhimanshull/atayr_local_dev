import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_card.dart';
import '../../models/friendship_model.dart';
import '../../models/friend_with_profile.dart';
import '../../services/friend_service.dart';
import 'friend_wardrobe_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        appBar: AppBar(
          backgroundColor: AtayrColors.background,
          elevation: 0,
          title: Text(
            'FRIENDS',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          iconTheme: const IconThemeData(color: AtayrColors.ink),
          bottom: const TabBar(
            labelColor: AtayrColors.ink,
            indicatorColor: AtayrColors.accent,
            tabs: [
              Tab(text: 'MY FRIENDS'),
              Tab(text: 'PENDING'),
              Tab(text: 'ADD FRIEND'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyFriendsTab(),
            _PendingRequestsTab(),
            _AddFriendTab(),
          ],
        ),
      ),
    );
  }
}

class _AddFriendTab extends StatefulWidget {
  const _AddFriendTab();

  @override
  State<_AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<_AddFriendTab> {
  String? _myInviteCode;
  bool _isLoading = true;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMyCode();
  }

  Future<void> _loadMyCode() async {
    try {
      final code = await context.read<FriendService>().getOrCreateInviteCode();
      if (mounted) setState(() { _myInviteCode = code; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading invite code: $e')));
      }
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await context.read<FriendService>().useInviteCode(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
        _codeController.clear();
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('PostgrestException')) {
          msg = msg.split('message: ').last.split(',').first;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeoCard(
          child: Column(
            children: [
              Text('YOUR INVITE CODE', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              _isLoading && _myInviteCode == null
                  ? const CircularProgressIndicator()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _myInviteCode ?? '---',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            if (_myInviteCode != null) {
                              Clipboard.setData(ClipboardData(text: _myInviteCode!));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                            }
                          },
                        ),
                      ],
                    ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        NeoCard(
          child: Column(
            children: [
              Text('ENTER INVITE CODE', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  hintText: 'Enter 6-character code',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: NeoButton(
                  label: _isLoading ? 'SUBMITTING...' : 'ADD FRIEND',
                  onPressed: _isLoading ? () {} : () => _submitCode(),
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingRequestsTab extends StatefulWidget {
  const _PendingRequestsTab();

  @override
  State<_PendingRequestsTab> createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends State<_PendingRequestsTab> {
  List<FriendshipModel>? _requests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reqs = await context.read<FriendService>().getPendingRequests();
    if (mounted) setState(() => _requests = reqs);
  }

  Future<void> _accept(String id) async {
    await context.read<FriendService>().acceptRequest(id);
    _load();
  }

  Future<void> _decline(String id) async {
    await context.read<FriendService>().declineRequest(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_requests == null) return const Center(child: CircularProgressIndicator());
    if (_requests!.isEmpty) return const Center(child: Text('No pending requests.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests!.length,
      itemBuilder: (context, index) {
        final req = _requests![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeoCard(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
              title: Text('User: ${req.userAId.substring(0, 8)}...'),
              subtitle: Text('Sent: ${req.createdAt.toLocal().toString().split('.')[0]}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _accept(req.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _decline(req.id),
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}

class _MyFriendsTab extends StatefulWidget {
  const _MyFriendsTab();

  @override
  State<_MyFriendsTab> createState() => _MyFriendsTabState();
}

class _MyFriendsTabState extends State<_MyFriendsTab> {
  List<FriendWithProfile>? _friends;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final f = await context.read<FriendService>().getFriendsWithProfiles();
    if (mounted) setState(() { _friends = f; _isLoading = false; });
  }

  Future<void> _removeFriend(String friendshipId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REMOVE FRIEND?'),
        content: const Text('Are you sure you want to remove this friend? They will no longer see your wardrobe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('REMOVE', style: TextStyle(color: AtayrColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await context.read<FriendService>().removeFriend(friendshipId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_friends == null || _friends!.isEmpty) return const Center(child: Text('No friends yet. Add some!'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _friends!.length,
      itemBuilder: (context, index) {
        final f = _friends![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeoCard(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
              leading: const CircleAvatar(backgroundColor: AtayrColors.accent, child: Icon(Icons.person, color: AtayrColors.ink)),
              title: Text(f.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${f.sharedItemCount} items • Since: ${f.friendsSince.toLocal().toString().split(' ')[0]}'),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove, color: AtayrColors.ink),
                onPressed: () => _removeFriend(f.friendshipId),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FriendWardrobeScreen(friend: f)),
                );
              },
            ),
            ),
          ),
        );
      },
    );
  }
}
