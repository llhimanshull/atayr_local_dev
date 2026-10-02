import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/atayr_colors.dart';
import '../../core/widgets/neo_card.dart';
import '../wardrobe/models/garment_model.dart';
import 'borrow_item_detail_screen.dart';

class BorrowScreen extends StatefulWidget {
  const BorrowScreen({super.key});

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  final _supabase = Supabase.instance.client;
  List<Garment> _sharedGarments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSharedGarments();
  }

  Future<void> _fetchSharedGarments() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // RLS policy will automatically filter out any garments we shouldn't see
      // We just need to query garments that aren't ours.
      final response = await _supabase
          .from('garments')
          .select()
          .neq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _sharedGarments = (response as List).map((g) => Garment.fromJson(g)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading borrow items: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AtayrColors.background,
        appBar: AppBar(
          backgroundColor: AtayrColors.background,
          elevation: 0,
          title: Text(
            'BORROW',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AtayrColors.ink),
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchSharedGarments();
              },
            ),
          ],
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AtayrColors.ink))
            : _sharedGarments.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'NO SHARED ITEMS FOUND.\n\nAsk your friends to share their garments!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AtayrColors.ink),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _sharedGarments.length,
                    itemBuilder: (context, index) {
                      final garment = _sharedGarments[index];
                      // Just grab the first 8 chars of the ID to represent the owner name
                      final ownerName = 'User: ${garment.userId.substring(0, 8)}...';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BorrowItemDetailScreen(
                                garment: garment,
                                ownerName: ownerName,
                              ),
                            ),
                          );
                        },
                        child: NeoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AtayrColors.ink, width: 1),
                                    color: AtayrColors.surface,
                                  ),
                                  child: Image.network(
                                    _supabase.storage.from('wardrobe').getPublicUrl(garment.studioImagePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                garment.name.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Owned by $ownerName',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
