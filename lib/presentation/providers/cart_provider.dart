import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Define the Product model structure used by the cart
class Product {
  final int id;
  final String name;
  final double sellingPrice;

  const Product({
    required this.id,
    required this.name,
    required this.sellingPrice,
  });
}

// 2. Define the exact EnhancedCartItem class expected by your POS screen layout
class EnhancedCartItem {
  final Product product;
  final int quantity;

  const EnhancedCartItem({
    required this.product,
    required this.quantity,
  });

  EnhancedCartItem copyWith({Product? product, int? quantity}) {
    return EnhancedCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

// 3. Create the Notifier state class that matches all method handles
class EnhancedCartNotifier extends StateNotifier<List<EnhancedCartItem>> {
  EnhancedCartNotifier() : super([]);

  // Adds an item to the checkout cart state
  void addToCart(Product product) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final existingItem = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        existingItem.copyWith(quantity: existingItem.quantity + 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, EnhancedCartItem(product: product, quantity: 1)];
    }
  }

  // Used by the refresh icon button and checkout sequence to clear the screen state
  void resetCartState() {
    state = [];
  }

  // Alias fallback to make absolutely sure no method handles crash
  void clearCart() {
    resetCartState();
  }
}

// 4. Expose the unified provider instance matching your updated UI file exactly
final enhancedCartProvider = StateNotifierProvider<EnhancedCartNotifier, List<EnhancedCartItem>>((ref) {
  return EnhancedCartNotifier();
});