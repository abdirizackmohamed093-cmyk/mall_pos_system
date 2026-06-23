import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// --- TABLE DEFINITIONS ---
class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get roleName => text().withLength(min: 1, max: 50)();
  TextColumn get permissionsJson => text()();
}

class Branches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get location => text().withLength(min: 1, max: 200)();
  TextColumn get contactNumber => text().nullable()();
  BoolColumn get isMainBranch => boolean().withDefault(const Constant(false))();
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().withLength(min: 3, max: 50).unique()();
  TextColumn get passwordHash => text()();
  IntColumn get roleId => integer().references(Roles, #id)();
  IntColumn get branchId => integer().references(Branches, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100).unique()();
  TextColumn get description => text().nullable()();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get sku => text().unique()();
  RealColumn get costPrice => real()();
  RealColumn get sellingPrice => real()();
  IntColumn get stockQuantity => integer()();
  IntColumn get reorderLevel => integer()();
  TextColumn get unitOfMeasure => text()();
  IntColumn get branchId => integer().references(Branches, #id)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get contactNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get totalAmount => real()();
  // ← NEW: VAT portion of totalAmount, stored separately so reports
  //        don't have to back-calculate it.
  RealColumn get vatAmount => real().withDefault(const Constant(0.0))();
  // ← NEW: needed to split the Z-Report into Cash vs M-Pesa totals.
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('Cash'))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  IntColumn get branchId => integer().references(Branches, #id)();
  IntColumn get cashierId => integer().references(Users, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get priceAtSale => real()();
}

// --- DATABASE SETUP ---
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'my_app_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [Roles, Branches, Users, Categories, Products, Customers, Sales, SaleItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultData();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(customers);
        await m.createTable(sales);
        await m.createTable(saleItems);
      } else if (from < 3) {
        await m.addColumn(sales, sales.vatAmount);
        await m.addColumn(sales, sales.paymentMethod);
      }
    },
  );

  Future<void> _seedDefaultData() async {
    final roleId = await into(roles).insert(
      RolesCompanion.insert(
        roleName: 'Owner',
        permissionsJson: '{"all":true}',
      ),
    );

    final branchId = await into(branches).insert(
      BranchesCompanion.insert(
        name: 'Main Branch',
        location: 'HQ',
        isMainBranch: const Value(true),
      ),
    );

    await into(users).insert(
      UsersCompanion.insert(
        username: 'admin',
        passwordHash: 'admin123',
        roleId: roleId,
        branchId: branchId,
      ),
    );
  }

  Future<double> getSalesSum(DateTime start) async {
    final query = selectOnly(sales)..addColumns([sales.totalAmount.sum()]);
    query.where(sales.timestamp.isBiggerOrEqualValue(start));
    final row = await query.getSingle();
    return row.read(sales.totalAmount.sum()) ?? 0.0;
  }

  Future<List<Sale>> getRecentTransactions(int limit) {
    return (select(sales)..orderBy([(s) => OrderingTerm.desc(s.timestamp)])..limit(limit)).get();
  }

  Future<int> insertProduct(ProductsCompanion entry) => into(products).insert(entry);

  Future<void> updateStock(int productId, int quantity, String type) async {
    final product = await (select(products)..where((p) => p.id.equals(productId))).getSingle();
    int newStock = product.stockQuantity;
    if (type == 'Stock In') {
      newStock += quantity;
    } else {
      newStock -= quantity;
    }
    if (newStock < 0) {
      throw Exception('Insufficient stock for ${product.name}');
    }
    await (update(products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(stockQuantity: Value(newStock)),
    );
  }

  Future<double> getGrossProfit(DateTime start) async {
    final query = select(saleItems).join([
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
      innerJoin(sales, sales.id.equalsExp(saleItems.saleId))
    ]);
    final expression = (saleItems.priceAtSale.cast<double>() - products.costPrice.cast<double>()) * saleItems.quantity.cast<double>();
    query.addColumns([expression.sum()]);
    query.where(sales.timestamp.isBiggerOrEqualValue(start));
    final row = await query.getSingle();
    return row.read(expression.sum()) ?? 0.0;
  }

  Future<double> getWeeklyRevenue() async {
    final start = DateTime.now().subtract(const Duration(days: 7));
    return getSalesSum(start);
  }

  Future<double> getMonthlyRevenue() async {
    final start = DateTime.now().subtract(const Duration(days: 30));
    return getSalesSum(start);
  }

  Future<int> getOutOfStockCount() async {
    final countExp = products.id.count();
    final query = selectOnly(products)..addColumns([countExp])..where(products.stockQuantity.equals(0));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> getLowStockCount() async {
    final countExp = products.id.count();
    final query = selectOnly(products)
      ..addColumns([countExp])
      ..where(
        products.stockQuantity.isSmallerThan(products.reorderLevel) & 
        products.stockQuantity.isBiggerThan(const Constant(0))
      );
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }
}
