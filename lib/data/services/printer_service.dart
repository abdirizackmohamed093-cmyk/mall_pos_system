import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PrinterService {
  Future<String> printReceipt({
    required List<CartItem> items,
    required double totalAmount,
    required double subtotal,
    required double vat,
    required String paymentMethod,
    required String cashierName,
    required int receiptNumber,
    double amountTendered = 0.0,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm, // 80mm receipt width
          double.infinity,       // auto height
          marginAll: 8 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────
              pw.Center(
                child: pw.Text(
                  'MALL POS SYSTEM',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Your Trusted Shopping Partner',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Tel: +254 700 000 000',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // ── Receipt Meta ─────────────────────────────────────
              pw.SizedBox(height: 4),
              _metaRow('Date', _formatDate(now)),
              _metaRow('Time', _formatTime(now)),
              _metaRow('Cashier', cashierName),
              _metaRow(
                'Receipt #',
                receiptNumber.toString().padLeft(6, '0'),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // ── Column Headers ───────────────────────────────────
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'ITEM',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text(
                      'QTY',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(
                    width: 45,
                    child: pw.Text(
                      'PRICE',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // ── Line Items ───────────────────────────────────────
              ...items.map((item) {
                final lineTotal = item.price * item.quantity;
                return pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          item.productName,
                          style:
                              const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.SizedBox(
                        width: 30,
                        child: pw.Text(
                          'x${item.quantity}',
                          style:
                              const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(
                        width: 45,
                        child: pw.Text(
                          _kes(item.price),
                          style:
                              const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.SizedBox(
                        width: 50,
                        child: pw.Text(
                          _kes(lineTotal),
                          style:
                              const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // ── Totals ───────────────────────────────────────────
              _totalRow('Subtotal', _kes(subtotal)),
              _totalRow('VAT (16%)', _kes(vat)),

              if (paymentMethod == 'Cash' && amountTendered > 0)
                ...[
                  _totalRow(
                    'Cash Tendered',
                    _kes(amountTendered),
                  ),
                  _totalRow(
                    'Change',
                    _kes(
                      amountTendered - totalAmount < 0
                          ? 0
                          : amountTendered - totalAmount,
                    ),
                  ),
                ],

              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL NET DUE',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _kes(totalAmount),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              _metaRow('Payment', paymentMethod),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),

              // ── Footer ───────────────────────────────────────────
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with us!',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Powered by Mall POS System',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    // ── Save to Desktop ──────────────────────────────────────────────
    final desktopPath = _getDesktopPath();
    final fileName =
        'Receipt_${receiptNumber.toString().padLeft(6, '0')}_${_fileTimestamp(now)}.pdf';
    final file = File('$desktopPath\\$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path; // returned so pos_screen can show the path in SnackBar
  }

  /// Generates the end-of-day Shift Z-Report as an A-receipt-width PDF
  /// and saves it to the desktop, returning the saved file path.
  Future<String> printZReport({
    required DateTime reportDate,
    required String branchName,
    required int transactionCount,
    required double grossSales,
    required double totalVat,
    required double netSales,
    required double cashTotal,
    required double mpesaTotal,
  }) async {
    final pdf = pw.Document();
    final generatedAt = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 8 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────
              pw.Center(
                child: pw.Text(
                  'MOHA SOLUTIONS',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'REPORTS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // ── Report Meta ───────────────────────────────────────
              pw.SizedBox(height: 4),
              _metaRow('Branch', branchName),
              _metaRow('Report Date', _formatDate(reportDate)),
              _metaRow('Generated', _formatTime(generatedAt)),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // ── Transaction Count ─────────────────────────────────
              pw.SizedBox(height: 6),
              _totalRow('Transactions', transactionCount.toString()),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // ── Sales Breakdown ───────────────────────────────────
              _totalRow('Net Sales', _kes(netSales)),
              _totalRow('VAT Collected (16%)', _kes(totalVat)),

              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'GROSS SALES',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _kes(grossSales),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // ── Payment Method Breakdown ──────────────────────────
              pw.Center(
                child: pw.Text(
                  'PAYMENT BREAKDOWN',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              _totalRow('Cash', _kes(cashTotal)),
              _totalRow('M-Pesa', _kes(mpesaTotal)),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),

              // ── Footer ───────────────────────────────────────────
              pw.Center(
                child: pw.Text(
                  'End of Report',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    final desktopPath = _getDesktopPath();
    final fileName = 'ZReport_${_fileTimestamp(reportDate)}.pdf';
    final file = File('$desktopPath\\$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _getDesktopPath() {
    // Windows desktop is always at %USERPROFILE%\Desktop
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    return '$userProfile\\Desktop';
  }

  pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _totalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  String _kes(double amount) =>
      'KES ${amount.toStringAsFixed(2)}';

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  String _fileTimestamp(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}_'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}';
}

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});

/// Frozen cart snapshot passed from pos_screen → printer_service.
class CartItem {
  final String productName;
  final int quantity;
  final double price;

  const CartItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });
}