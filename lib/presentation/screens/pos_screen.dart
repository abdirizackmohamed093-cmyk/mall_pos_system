import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cart_provider.dart';
import '../providers/product_notifier.dart';
import '../providers/session_provider.dart';

import '../../data/repositories/sales_repository.dart';
import '../../data/services/printer_service.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _selectedMethod = "Cash";
  bool _isProcessing = false; // ← prevents double-tap race conditions
  bool _isGeneratingReport = false; // ← prevents double-tap on Z-Report

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(enhancedCartProvider);
    final productsAsync = ref.watch(productNotifierProvider);

    double subtotal = 0;
    for (final item in cartItems) {
      subtotal += item.product.sellingPrice * item.quantity;
    }

    final double vat = subtotal * 0.16;
    final double totalDue = subtotal + vat;

    return Scaffold(
      appBar: AppBar(
        title: const Text("MALL POINT OF SALE SYSTEM"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref
                  .read(productNotifierProvider.notifier)
                  .refreshProducts();
              ref.read(enhancedCartProvider.notifier).resetCartState();
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // ── LEFT: Product Grid ────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search by product name or SKU...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: productsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          Center(child: Text("Error: $err")),
                      data: (products) {
                        if (products.isEmpty) {
                          return const Center(
                              child: Text("No products available"));
                        }

                        final filteredProducts = (_searchQuery.isEmpty
                            ? List<LocalProduct>.from(products)
                            : products.where((item) {
                                final name = item.name.toLowerCase();
                                final sku = item.sku.toLowerCase();
                                return name.contains(_searchQuery) ||
                                    sku.contains(_searchQuery);
                              }).toList())
                          ..sort((a, b) =>
                              a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                        if (filteredProducts.isEmpty) {
                          return Center(
                            child: Text(
                              'No products match "$_searchQuery"',
                              style:
                                  const TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final item = filteredProducts[index];
                            final outOfStock = item.stockQuantity <= 0;

                            return Card(
                              color: outOfStock
                                  ? Colors.red.shade50
                                  : Colors.white,
                              child: InkWell(
                                onTap: outOfStock
                                    ? null
                                    : () {
                                        ref
                                            .read(enhancedCartProvider
                                                .notifier)
                                            .addToCart(item.toProduct());
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name.toUpperCase(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "SKU: ${item.sku}",
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey),
                                      ),
                                      const Spacer(),
                                      Text("Stock: ${item.stockQuantity}"),
                                      const SizedBox(height: 4),
                                      Text(
                                        "KES ${item.sellingPrice.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── RIGHT: Cart & Checkout Panel ─────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Z-Report button
                  ElevatedButton.icon(
                    icon: _isGeneratingReport
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.receipt_long,
                            color: Colors.white),
                    label: Text(
                      _isGeneratingReport
                          ? "GENERATING REPORT..."
                          : "GENERATE SHIFT Z-REPORT",
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isGeneratingReport
                        ? null
                        : () async {
                            setState(
                                () => _isGeneratingReport = true);

                            try {
                              final session =
                                  ref.read(sessionProvider);
                              if (session == null) {
                                throw Exception(
                                    "No active cashier session.");
                              }

                              final reportData = await ref
                                  .read(salesRepositoryProvider)
                                  .getZReportData(
                                    branchId: session.branchId,
                                    date: DateTime.now(),
                                  );

                              final filePath = await ref
                                  .read(printerServiceProvider)
                                  .printZReport(
                                    reportDate: DateTime.now(),
                                    branchName: session.branchName,
                                    transactionCount:
                                        reportData.transactionCount,
                                    grossSales:
                                        reportData.grossSales,
                                    totalVat: reportData.totalVat,
                                    netSales: reportData.netSales,
                                    cashTotal: reportData.cashTotal,
                                    mpesaTotal:
                                        reportData.mpesaTotal,
                                  );

                              if (!mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Z-Report saved: $filePath"),
                                  backgroundColor:
                                      Colors.blueGrey,
                                  duration:
                                      const Duration(seconds: 6),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "ERROR: ${e.toString()}",
                                    style: const TextStyle(
                                        fontSize: 12),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration:
                                      const Duration(seconds: 8),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() =>
                                    _isGeneratingReport = false);
                              }
                            }
                          },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "Current Customer Cart",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  // Cart items list
                  Expanded(
                    child: cartItems.isEmpty
                        ? const Center(
                            child: Text("Cart is empty",
                                style:
                                    TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final cartItem = cartItems[index];
                              final itemTotal =
                                  cartItem.product.sellingPrice *
                                      cartItem.quantity;

                              return ListTile(
                                title: Text(cartItem.product.name),
                                subtitle: Text(
                                    "Qty: ${cartItem.quantity}"),
                                trailing: Text(
                                    "KES ${itemTotal.toStringAsFixed(2)}"),
                              );
                            },
                          ),
                  ),

                  const Divider(),

                  // Payment method
                  const Text(
                    "Payment Method",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("Cash"),
                          value: "Cash",
                          groupValue: _selectedMethod,
                          onChanged: _isProcessing
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(
                                      () => _selectedMethod = value);
                                },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("M-Pesa"),
                          value: "M-Pesa",
                          groupValue: _selectedMethod,
                          onChanged: _isProcessing
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(
                                      () => _selectedMethod = value);
                                },
                        ),
                      ),
                    ],
                  ),

                  const Divider(),

                  // Subtotal / VAT / Total breakdown
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Subtotal:"),
                        Text(
                            "KES ${subtotal.toStringAsFixed(2)}"),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("VAT (16%):"),
                        Text("KES ${vat.toStringAsFixed(2)}"),
                      ],
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "TOTAL NET DUE: KES ${totalDue.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // ── CHECKOUT BUTTON ───────────────────────────────────
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize:
                          const Size(double.infinity, 55),
                    ),
                    onPressed: (totalDue <= 0 || _isProcessing)
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);

                            try {
                              // ── STEP 1: Validate session ──────────────
                              final session =
                                  ref.read(sessionProvider);
                              if (session == null) {
                                throw Exception(
                                    "No active cashier session.");
                              }

                              // ── STEP 2: Freeze cart snapshot BEFORE
                              //           any DB write or cart clear ──────
                              final frozenCart =
                                  List<EnhancedCartItem>.from(
                                      cartItems);
                              final frozenTotal = totalDue;
                              final frozenSubtotal = subtotal;
                              final frozenVat = vat;
                              final frozenMethod = _selectedMethod;
                              final cashierName = session.username;

                              // ── STEP 3: Save sale to DB, get saleId ──
                              final saleId = await ref
                                  .read(salesRepositoryProvider)
                                  .executeCheckout(
                                    branchId: session.branchId,
                                    cashierId: session.userId,
                                    cartItems: frozenCart,
                                    paymentMethod: frozenMethod,
                                  );

                              // ── STEP 4: Print receipt using frozen
                              //           snapshot (cart not yet cleared) ─
                              final printerItems = frozenCart
                                  .map(
                                    (e) => CartItem(
                                      productName: e.product.name,
                                      quantity: e.quantity,
                                      price:
                                          e.product.sellingPrice,
                                    ),
                                  )
                                  .toList();

                              await ref
                                  .read(printerServiceProvider)
                                  .printReceipt(
                                    items: printerItems,
                                    totalAmount: frozenTotal,
                                    subtotal: frozenSubtotal,
                                    vat: frozenVat,
                                    paymentMethod: frozenMethod,
                                    cashierName: cashierName,
                                    receiptNumber: saleId,
                                  );

                              // ── STEP 5: Refresh product stock display ─
                              await ref
                                  .read(productNotifierProvider
                                      .notifier)
                                  .refreshProducts();

                              // ── STEP 6: Clear cart LAST ───────────────
                              ref
                                  .read(enhancedCartProvider
                                      .notifier)
                                  .resetCartState();

                              if (!mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Sale completed & receipt printed."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;

                              // Surface the real error — never swallow silently
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "ERROR: ${e.toString()}",
                                    style: const TextStyle(
                                        fontSize: 12),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration:
                                      const Duration(seconds: 8),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(
                                    () => _isProcessing = false);
                              }
                            }
                          },
                    child: _isProcessing
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "PROCEED AND PRINT RECEIPT",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
