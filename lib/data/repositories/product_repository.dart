import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

class ProductRepository {
  final AppDatabase _db;
  ProductRepository(this._db);

  // Fetch all products across branches
  Future<List<Product>> getAllProducts() async {
    return await _db.select(_db.products).get();
  }

  // Stream live updates for real-time stock changes
  Stream<List<Product>> watchAllProducts() {
    return _db.select(_db.products).watch();
  }

  // Insert a new product into the database
  Future<int> insertProduct(ProductsCompanion product) async {
    return await _db.into(_db.products).insert(product);
  }

  // Safely update existing product information
  Future<bool> updateProduct(Product product) async {
    return await _db.update(_db.products).replace(product);
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});