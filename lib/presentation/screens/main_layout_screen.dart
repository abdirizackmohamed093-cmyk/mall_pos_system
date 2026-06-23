import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Using your exact file names present in the folder structure
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'stock_entry_screen.dart';

// Global state provider to track the index of the selected sidebar menu item
final navigationIndexProvider = StateProvider<int>((ref) => 0);

class MainLayoutScreen extends ConsumerWidget {
  const MainLayoutScreen({super.key});

  List<Widget> _getScreens() {
    return [
      const PosScreen(),       // Index 0 (Linked to pos_screen.dart)
      const InventoryScreen(), // Index 1 (Linked to inventory_screen.dart)
      const StockEntryScreen(), // Index 2 (Linked to stock_entry_screen.dart)
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final screens = _getScreens();

    return Scaffold(
      body: Row(
        children: [
          // --- FIXED SIDE NAVIGATION BAR ---
          Container(
            width: 240,
            color: const Color(0xFF222E35), // Dark slate aesthetic background
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFF1A2429)),
                  child: Center(
                    child: Text(
                      'MALL POS SYSTEM',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                _buildSidebarTile(
                  ref: ref,
                  icon: Icons.shopping_cart,
                  title: 'POS Checkout',
                  index: 0,
                  isActive: currentIndex == 0,
                ),
                _buildSidebarTile(
                  ref: ref,
                  icon: Icons.dashboard,
                  title: 'Inventory Dashboard',
                  index: 1,
                  isActive: currentIndex == 1,
                ),
                _buildSidebarTile(
                  ref: ref,
                  icon: Icons.add_box,
                  title: 'Stock Entry',
                  index: 2,
                  isActive: currentIndex == 2,
                ),
              ],
            ),
          ),

          // --- ACTIVE DYNAMIC SCREEN MAIN WORKSPACE ---
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7F8), // App workspace background canvas tint
              child: IndexedStack(
                index: currentIndex,
                children: screens,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar interactive layout row builder
  Widget _buildSidebarTile({
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required int index,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () {
        ref.read(navigationIndexProvider.notifier).state = index;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isActive ? const Color(0xFF00A896).withOpacity(0.15) : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF00A896) : Colors.blueGrey.shade300,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? const Color(0xFF00A896) : Colors.blueGrey.shade200,
              ),
            ),
          ],
        ),
      ),
    );
  }
}