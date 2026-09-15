import 'package:flutter/material.dart';
import '../../core/theme/atayr_colors.dart';
import '../home/home_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../profile/profile_screen.dart';
import '../borrow/borrow_screen.dart';
import '../extraction/extraction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    WardrobeScreen(),
    // ADD is index 2, handled outside this list
    BorrowScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // ADD action tapped - open Extraction screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ExtractionScreen()),
      );
      return;
    }
    
    // Adjust index because "Add" is physically in the middle but not in the screen array
    int screenIndex = index > 2 ? index - 1 : index;
    
    setState(() {
      _currentIndex = screenIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AtayrColors.ink, width: 3)),
          color: AtayrColors.background,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AtayrColors.background,
          selectedItemColor: AtayrColors.ink,
          unselectedItemColor: AtayrColors.ink.withValues(alpha: 0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'HOME'),
            const BottomNavigationBarItem(icon: Icon(Icons.checkroom_outlined), activeIcon: Icon(Icons.checkroom), label: 'WARDROBE'),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AtayrColors.accent,
                  border: Border.all(color: AtayrColors.ink, width: 2),
                ),
                child: const Icon(Icons.add, color: AtayrColors.ink, size: 28),
              ),
              label: 'ADD',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.handshake_outlined), activeIcon: Icon(Icons.handshake), label: 'BORROW'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }
}
