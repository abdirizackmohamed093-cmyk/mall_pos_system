import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/app_database.dart' show ProductsCompanion;
import './cart_provider.dart'; // REQUIRED: Import your cart provider to see the original 'Product' class

class LocalProduct {
  final int id;
  final String name;
  final double sellingPrice;
  final double costPrice;
  final int stockQuantity;
  final int reorderLevel;
  final String unitOfMeasure;
  final String sku;

  const LocalProduct({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.costPrice,
    required this.stockQuantity,
    required this.reorderLevel,
    required this.unitOfMeasure,
    required this.sku,
  });

  // ADD THIS HELPER METHOD: Converts LocalProduct to the core Product type
  Product toProduct() {
    return Product(
      id: id,
      name: name,
      sellingPrice: sellingPrice,
    );
  }
}

// Keep the rest of your ProductNotifier class exactly the same as before...
class ProductNotifier extends StateNotifier<AsyncValue<List<LocalProduct>>> {
  final Ref _ref;
  ProductNotifier(this._ref) : super(const AsyncLoading()) {
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final database = _ref.read(databaseProvider);
      final rows = await database.select(database.products).get();
      final productList = rows.map((row) => LocalProduct(
        id: row.id,
        name: row.name,
        sellingPrice: row.sellingPrice,
        costPrice: row.costPrice,
        stockQuantity: row.stockQuantity,
        reorderLevel: row.reorderLevel,
        unitOfMeasure: row.unitOfMeasure,
        sku: row.sku,
      )).toList();
      state = AsyncValue.data(productList);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refreshProducts() async {
    await fetchProducts();
  }

  /// Updates an existing product's editable fields, then refreshes the list.
  Future<void> updateProduct({
    required int id,
    required String name,
    required String sku,
    required double costPrice,
    required double sellingPrice,
    required int stockQuantity,
  }) async {
    final database = _ref.read(databaseProvider);

    await (database.update(database.products)
          ..where((p) => p.id.equals(id)))
        .write(
      ProductsCompanion(
        name: Value(name),
        sku: Value(sku),
        costPrice: Value(costPrice),
        sellingPrice: Value(sellingPrice),
        stockQuantity: Value(stockQuantity),
      ),
    );

    await fetchProducts();
  }

  /// Deletes a product. If it already has sales history linked to it,
  /// the foreign key constraint on SaleItems will block the delete —
  /// we surface that as a clear message instead of a raw SQL error.
  Future<void> deleteProduct(int id) async {
    final database = _ref.read(databaseProvider);

    try {
      await (database.delete(database.products)..where((p) => p.id.equals(id)))
          .go();
      await fetchProducts();
    } catch (e) {
      throw Exception(
        'Cannot delete this product — it already has sales history linked to it.',
      );
    }
  }
}

final productNotifierProvider = StateNotifierProvider<ProductNotifier, AsyncValue<List<LocalProduct>>>((ref) {
  return ProductNotifier(ref);
});