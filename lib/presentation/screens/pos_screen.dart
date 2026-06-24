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
  bool _isProcessing = false;
  bool _isGeneratingReport = false;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tenderedController = TextEditingController(); // ← NEW
  String _searchQuery = "";
  double _amountTendered = 0.0; // ← NEW

  @override
  void dispose() {
    _searchController.dispose();
    _tenderedController.dispose(); // ← NEW
    super.dispose();
  }

  // ── Checkout allowed only when tendered covers total (Cash) ──────────────
  bool _checkoutAllowed(double totalDue) {
    if (totalDue <= 0 || _isProcessing) return false;
    if (_selectedMethod == "Cash" && _amountTendered < totalDue) return false;
    return true;
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
    final double changeDue = _amountTendered - totalDue;

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
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
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
                          ..sort((a, b) => a.name
                              .toLowerCase()
                              .compareTo(b.name.toLowerCase()));

                        if (filteredProducts.isEmpty) {
                          return Center(
                            child: Text(
                              'No products match "$_searchQuery"',
                              style: const TextStyle(color: Colors.grey),
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
                        : const Icon(Icons.receipt_long, color: Colors.white),
                    label: Text(
                      _isGeneratingReport
                          ? "GENERATING REPORT..."
                          : "GENERATE SHIFT Z-REPORT",
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isGeneratingReport
                        ? null
                        : () async {
                            setState(() => _isGeneratingReport = true);

                            try {
                              final session = ref.read(sessionProvider);
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
                                    grossSales: reportData.grossSales,
                                    totalVat: reportData.totalVat,
                                    netSales: reportData.netSales,
                                    cashTotal: reportData.cashTotal,
                                    mpesaTotal: reportData.mpesaTotal,
                                  );

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Z-Report saved: $filePath"),
                                  backgroundColor: Colors.blueGrey,
                                  duration: const Duration(seconds: 6),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "ERROR: ${e.toString()}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 8),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isGeneratingReport = false);
                              }
                            }
                          },
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Current Customer Cart",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  // Cart items list
                  Expanded(
                    child: cartItems.isEmpty
                        ? const Center(
                            child: Text("Cart is empty",
                                style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final cartItem = cartItems[index];
                              final itemTotal =
                                  cartItem.product.sellingPrice *
                                      cartItem.quantity;

                              return ListTile(
                                dense: true,
                                title: Text(cartItem.product.name),
                                subtitle:
                                    Text("Qty: ${cartItem.quantity}"),
                                trailing: Text(
                                  "KES ${itemTotal.toStringAsFixed(2)}",
                                ),
                              );
                            },
                          ),
                  ),

                  const Divider(),

                  // ── Payment Method ────────────────────────────────────
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
                                  setState(() {
                                    _selectedMethod = value;
                                    _tenderedController.clear();
                                    _amountTendered = 0.0;
                                  });
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
                                  setState(() {
                                    _selectedMethod = value;
                                    _tenderedController.clear();
                                    _amountTendered = 0.0;
                                  });
                                },
                        ),
                      ),
                    ],
                  ),

                  // ── Cash Tendered input (Cash only) ───────────────────
                  if (_selectedMethod == "Cash") ...[
                    TextField(
                      controller: _tenderedController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      enabled: !_isProcessing,
                      decoration: InputDecoration(
                        labelText: "Cash Tendered (KES)",
                        hintText: "Enter amount received from customer",
                        prefixIcon:
                            const Icon(Icons.payments_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _amountTendered =
                              double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Change due / short badge
                    if (_amountTendered > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: changeDue >= 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: changeDue >= 0
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              changeDue >= 0
                                  ? "Change Due:"
                                  : "Amount Short:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: changeDue >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                            Text(
                              "KES ${changeDue.abs().toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: changeDue >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 4),
                  ],

                  const Divider(),

                  // ── Subtotal / VAT / Total ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Subtotal:",
                            style: TextStyle(color: Colors.black54)),
                        Text("KES ${subtotal.toStringAsFixed(2)}",
                            style:
                                const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("VAT (16%):",
                            style: TextStyle(color: Colors.black54)),
                        Text("KES ${vat.toStringAsFixed(2)}",
                            style:
                                const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "TOTAL NET DUE: KES ${totalDue.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // ── Checkout Button ───────────────────────────────────
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      disabledBackgroundColor: Colors.grey.shade400,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    onPressed: _checkoutAllowed(totalDue)
                        ? () async {
                            setState(() => _isProcessing = true);

                            try {
                              // STEP 1: Validate session
                              final session = ref.read(sessionProvider);
                              if (session == null) {
                                throw Exception(
                                    "No active cashier session.");
                              }

                              // STEP 2: Freeze everything BEFORE DB write
                              final frozenCart =
                                  List<EnhancedCartItem>.from(cartItems);
                              final frozenTotal = totalDue;
                              final frozenSubtotal = subtotal;
                              final frozenVat = vat;
                              final frozenMethod = _selectedMethod;
                              final frozenTendered = _amountTendered;
                              final cashierName = session.username;

                              // STEP 3: Save to DB, get saleId
                              final saleId = await ref
                                  .read(salesRepositoryProvider)
                                  .executeCheckout(
                                    branchId: session.branchId,
                                    cashierId: session.userId,
                                    cartItems: frozenCart,
                                    paymentMethod: frozenMethod,
                                  );

                              // STEP 4: Print receipt from frozen snapshot
                              final printerItems = frozenCart
                                  .map((e) => CartItem(
                                        productName: e.product.name,
                                        quantity: e.quantity,
                                        price: e.product.sellingPrice,
                                      ))
                                  .toList();

                              final savedPath = await ref
                                  .read(printerServiceProvider)
                                  .printReceipt(
                                    items: printerItems,
                                    totalAmount: frozenTotal,
                                    subtotal: frozenSubtotal,
                                    vat: frozenVat,
                                    paymentMethod: frozenMethod,
                                    cashierName: cashierName,
                                    receiptNumber: saleId,
                                    amountTendered: frozenTendered,
                                  );

                              // STEP 5: Refresh stock
                              await ref
                                  .read(productNotifierProvider.notifier)
                                  .refreshProducts();

                              // STEP 6: Clear cart and tendered LAST
                              ref
                                  .read(enhancedCartProvider.notifier)
                                  .resetCartState();

                              setState(() {
                                _amountTendered = 0.0;
                                _tenderedController.clear();
                              });

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Sale complete. Receipt saved:\n$savedPath"),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 6),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "ERROR: ${e.toString()}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 8),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isProcessing = false);
                              }
                            }
                          }
                        : null,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _selectedMethod == "Cash" &&
                                    _amountTendered < totalDue &&
                                    totalDue > 0
                                ? "ENTER CASH AMOUNT TO PROCEED"
                                : "PROCEED AND PRINT RECEIPT",
                            style: const TextStyle(
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