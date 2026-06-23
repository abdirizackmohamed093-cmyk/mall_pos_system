import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/database/database_provider.dart';

final recentSalesProvider = StreamProvider<List<QueryRow>>((ref) {
  final database = ref.read(databaseProvider);
  return database.customSelect(
    'SELECT * FROM sales ORDER BY timestamp DESC LIMIT 10',
  ).watch();
});