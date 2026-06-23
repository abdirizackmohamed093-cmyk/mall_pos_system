import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'dart:io';
import '../database/database_provider.dart';

final reportServiceProvider = Provider((ref) => ReportService(ref));

class ReportService {
  final Ref _ref;
  ReportService(this._ref);

  Future<String> generateDailyReport({required int cashierId}) async {
    final database = _ref.read(databaseProvider);
    final now = DateTime.now();
    final String todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    double totalCash = 0;
    double totalMpesa = 0;
    int totalTransactions = 0;

    try {
      // Query computing transaction aggregates across daily intervals via explicit raw relational joins
      final List<QueryRow> rows = await database.customSelect(
        'SELECT s.total_amount, p.payment_method FROM sales s JOIN payments p ON s.id = p.sale_id WHERE s.timestamp LIKE ?',
        variables: [Variable.withString('$todayString%')],
      ).get();

      totalTransactions = rows.length;

      for (var row in rows) {
        final double totalAmount = row.read<double>('total_amount');
        final String method = row.read<String>('payment_method').toLowerCase();

        if (method == 'cash') {
          totalCash += totalAmount;
        } else if (method == 'm-pesa' || method == 'mpesa') {
          totalMpesa += totalAmount;
        }
      }
    } catch (e) {
      return "Failed executing matrix compilation context metrics: $e";
    }

    double grandTotal = totalCash + totalMpesa;
    final StringBuffer report = StringBuffer();
    report.writeln("========================================");
    report.writeln("         DAILY SALES SUMMARY REPORT     ");
    report.writeln("               (X-REPORT)               ");
    report.writeln("========================================");
    report.writeln("Date/Time Generated: ${now.toString().substring(0, 19)}");
    report.writeln("Cashier ID:          #00$cashierId");
    report.writeln("----------------------------------------");
    report.writeln("Total Cash:          KES ${totalCash.toStringAsFixed(1)}");
    report.writeln("Total M-Pesa:        KES ${totalMpesa.toStringAsFixed(1)}");
    report.writeln("----------------------------------------");
    report.writeln("TOTAL COMBINED:      KES ${grandTotal.toStringAsFixed(1)}");
    report.writeln("Total Transactions:  $totalTransactions");
    report.writeln("========================================");

    try {
      final String userName = Platform.environment['USERNAME'] ?? 'User';
      final String desktopPath = 'C:\\Users\\$userName\\Desktop\\daily_report_summary.txt';
      final File file = File(desktopPath);
      await file.writeAsString(report.toString());
      return "Report exported successfully to Desktop!";
    } catch (e) {
      return "Failed to save file to Desktop: $e";
    }
  }
}