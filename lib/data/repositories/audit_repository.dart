import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

class AuditRepository {
  final AppDatabase _db;
  AuditRepository(this._db);

  // Fetch all historical system logs
  Future<List<InventoryMovement>> getMovementLogs() async {
    return await _db.select(_db.inventoryMovements).get();
  }

  // Create an intentional operational stock adjustment log row
  Future<int> logManualAdjustment({
    required int productId,
    required int quantityChanged,
    required String reason,
  }) async {
    return await _db.into(_db.inventoryMovements).insert(
      InventoryMovementsCompanion.insert(
        productId: productId,
        movementType: "Adjustment",
        quantityChanged: quantityChanged,
        reason: Value(reason),
        timestamp: Value(DateTime.now()),
      ),
    );
  }
}

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepository(ref.watch(databaseProvider));
});