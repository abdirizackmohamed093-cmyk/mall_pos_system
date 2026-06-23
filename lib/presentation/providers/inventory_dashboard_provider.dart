import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart'; // reuse the SINGLE global instance

class ProductRanking {
  final String name;
  final int quantitySold;
  ProductRanking({required this.name, required this.quantitySold});
}

class CustomerRanking {
  final String name;
  final double totalSpent;
  CustomerRanking({required this.name, required this.totalSpent});
}

class DashboardMetrics {
  final double todayRevenue;
  final double weeklyRevenue;
  final double monthlyRevenue;
  final double grossProfit;
  final int outOfStock;
  final int lowStock;
  final List<Sale> recentSales;
  final List<User> activeCashiers;
  final List<ProductRanking> topProducts;
  final List<CustomerRanking> topCustomers;

  DashboardMetrics({
    required this.todayRevenue,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.grossProfit,
    required this.outOfStock,
    required this.lowStock,
    required this.recentSales,
    required this.activeCashiers,
    required this.topProducts,
    required this.topCustomers,
  });
}

final dashboardMetricsProvider = StreamProvider<DashboardMetrics>((ref) async* {
  final db = ref.watch(databaseProvider); // <- the one true global AppDatabase

  while (true) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayRev = await db.getSalesSum(todayStart);
    final weekRev = await db.getWeeklyRevenue();
    final monthRev = await db.getMonthlyRevenue();
    final profit = await db.getGrossProfit(todayStart);

    final outStock = await db.getOutOfStockCount();
    final lowStockCount = await db.getLowStockCount();

    final sales = await db.getRecentTransactions(5);

    final activeUsers =
        await (db.select(db.users)..where((u) => u.isActive.equals(true))).get();

    // Top 3 products by units sold
    final productQuery = db.selectOnly(db.saleItems).join([
      innerJoin(db.products, db.products.id.equalsExp(db.saleItems.productId)),
    ]);
    final productQtySum = db.saleItems.quantity.sum();
    productQuery
      ..addColumns([db.products.name, productQtySum])
      ..groupBy([db.saleItems.productId])
      ..orderBy([OrderingTerm.desc(productQtySum)])
      ..limit(3);
    final topProdRows = await productQuery.get();
    final topProducts = topProdRows
        .map((row) => ProductRanking(
              name: row.read(db.products.name) ?? 'Unknown',
              quantitySold: row.read(productQtySum) ?? 0,
            ))
        .toList();

    // Top 5 customers by spend
    final customerQuery = db.selectOnly(db.sales).join([
      innerJoin(db.customers, db.customers.id.equalsExp(db.sales.customerId)),
    ]);
    final customerSpendingSum = db.sales.totalAmount.sum();
    customerQuery
      ..addColumns([db.customers.name, customerSpendingSum])
      ..groupBy([db.sales.customerId])
      ..orderBy([OrderingTerm.desc(customerSpendingSum)])
      ..limit(5);
    final topCustRows = await customerQuery.get();
    final topCustomers = topCustRows
        .map((row) => CustomerRanking(
              name: row.read(db.customers.name) ?? 'Unknown',
              totalSpent: row.read(customerSpendingSum) ?? 0,
            ))
        .toList();

    yield DashboardMetrics(
      todayRevenue: todayRev,
      weeklyRevenue: weekRev,
      monthlyRevenue: monthRev,
      grossProfit: profit,
      outOfStock: outStock,
      lowStock: lowStockCount,
      recentSales: sales,
      activeCashiers: activeUsers,
      topProducts: topProducts,
      topCustomers: topCustomers,
    );

    await Future.delayed(const Duration(seconds: 5));
  }
});