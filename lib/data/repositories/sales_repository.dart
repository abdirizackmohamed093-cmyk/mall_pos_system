import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../../presentation/providers/cart_provider.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.read(databaseProvider));
});

/// Aggregated totals for a single day, used to print the Z-Report.
class ZReportData {
  final DateTime reportDate;
  final int transactionCount;
  final double grossSales;
  final double totalVat;
  final double netSales;
  final double cashTotal;
  final double mpesaTotal;

  const ZReportData({
    required this.reportDate,
    required this.transactionCount,
    required this.grossSales,
    required this.totalVat,
    required this.netSales,
    required this.cashTotal,
    required this.mpesaTotal,
  });
}

class SalesRepository {
  final AppDatabase _db;

  SalesRepository(this._db);

  Future<int> executeCheckout({
    required int branchId,
    required int cashierId,
    required List<EnhancedCartItem> cartItems,
    required String paymentMethod,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Cannot checkout an empty cart.');
    }

    final int saleId = await _db.transaction(() async {
      double subtotal = 0;

      for (final item in cartItems) {
        final product = await (_db.select(_db.products)
              ..where((p) => p.id.equals(item.product.id)))
            .getSingle();

        if (product.stockQuantity < item.quantity) {
          throw Exception(
            'Insufficient stock for ${product.name}',
          );
        }

        subtotal += item.product.sellingPrice * item.quantity;
      }

      // ← FIX: totalAmount now correctly stores subtotal + VAT
      //        (it previously stored subtotal only).
      final double vat = subtotal * 0.16;
      final double grandTotal = subtotal + vat;

      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              totalAmount: grandTotal,
              vatAmount: Value(vat),
              paymentMethod: Value(paymentMethod),
              branchId: branchId,
              cashierId: cashierId,
            ),
          );

      for (final item in cartItems) {
        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: item.product.id,
                quantity: item.quantity,
                priceAtSale: item.product.sellingPrice,
              ),
            );

        final product = await (_db.select(_db.products)
              ..where((p) => p.id.equals(item.product.id)))
            .getSingle();

        final updatedStock = product.stockQuantity - item.quantity;

        await (_db.update(_db.products)
              ..where((p) => p.id.equals(item.product.id)))
            .write(
          ProductsCompanion(
            stockQuantity: Value(updatedStock),
          ),
        );
      }

      return saleId;
    });

    return saleId;
  }

  Future<List<Sale>> getRecentSales({int limit = 20}) {
    return (_db.select(_db.sales)
          ..orderBy([(s) => OrderingTerm.desc(s.timestamp)])
          ..limit(limit))
        .get();
  }

  /// Aggregates every sale at [branchId] for the calendar day containing
  /// [date], across all cashiers, into the totals needed for the
  /// Shift Z-Report.
  Future<ZReportData> getZReportData({
    required int branchId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final salesForDay = await (_db.select(_db.sales)
          ..where((s) =>
              s.branchId.equals(branchId) &
              s.timestamp.isBiggerOrEqualValue(startOfDay) &
              s.timestamp.isSmallerThanValue(endOfDay)))
        .get();

    double grossSales = 0;
    double totalVat = 0;
    double cashTotal = 0;
    double mpesaTotal = 0;

    for (final sale in salesForDay) {
      grossSales += sale.totalAmount;
      totalVat += sale.vatAmount;

      if (sale.paymentMethod == 'Cash') {
        cashTotal += sale.totalAmount;
      } else {
        mpesaTotal += sale.totalAmount;
      }
    }

    return ZReportData(
      reportDate: date,
      transactionCount: salesForDay.length,
      grossSales: grossSales,
      totalVat: totalVat,
      netSales: grossSales - totalVat,
      cashTotal: cashTotal,
      mpesaTotal: mpesaTotal,
    );
  }
}