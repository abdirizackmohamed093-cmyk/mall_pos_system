import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/database/database_provider.dart';
import 'cart_provider.dart'; // To see the core Product model

class StockAdjustmentNotifier extends StateNotifier<void> {
  final Ref _ref;
  StockAdjustmentNotifier(this._ref) : super(null);

  Future<void> submitAdjustment({
    required Product product,
    required int quantity,
    required String type,
    required String reason,
  }) async {
    final database = _ref.read(databaseProvider);
    final String nowIso = DateTime.now().toIso8601String();

    // Map your UI action types to database movement types
    String dbMovementType = 'Adjustment';
    if (type == 'Stock In') dbMovementType = 'Stock In';
    if (type == 'Stock Out') dbMovementType = 'Stock Out';

    await database.transaction(() async {
      // 1. Insert into inventory_movements history table logs
      await database.customStatement(
        'INSERT INTO inventory_movements (product_id, movement_type, quantity_changed, reason, timestamp) VALUES (?, ?, ?, ?, ?)',
        [product.id, dbMovementType, quantity, reason, nowIso],
      );

      // 2. Fetch current stock balance dynamically
      final List<QueryRow> currentRows = await database.customSelect(
        'SELECT stock_quantity FROM products WHERE id = ?',
        variables: [Variable.withInt(product.id)],
      ).get();

      if (currentRows.isNotEmpty) {
        final int currentStock = currentRows.first.read<int>('stock_quantity');
        int newStock = currentStock;

        if (type == 'Stock In') {
          newStock = currentStock + quantity;
        } else if (type == 'Stock Out' || type == 'Adjustment') {
          newStock = currentStock - quantity;
        }

        if (newStock < 0) newStock = 0;

        // 3. Apply changes directly onto product stock quantity rows
        await database.customStatement(
          'UPDATE products SET stock_quantity = ? WHERE id = ?',
          [newStock, product.id],
        );
      }
    });
  }
}

// Global provider declaration
final stockAdjustmentNotifierProvider = StateNotifierProvider<StockAdjustmentNotifier, void>((ref) {
  return StockAdjustmentNotifier(ref);
});