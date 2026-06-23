import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/product_notifier.dart';
import '../providers/inventory_dashboard_provider.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/app_database.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddProductDialogForm(),
    );
  }

  void _showEditProductDialog(BuildContext context, LocalProduct product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditProductDialogForm(product: product),
    );
  }

  Future<void> _confirmDeleteProduct(
      BuildContext context, LocalProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product?"),
        content: Text(
          'Are you sure you want to delete "${product.name.toUpperCase()}" '
          '(SKU: ${product.sku})? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(productNotifierProvider.notifier).deleteProduct(product.id);
      ref.invalidate(dashboardMetricsProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${product.name.toUpperCase()}" was deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productNotifierProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("BUSINESS MANAGEMENT & ANALYTICS DASHBOARD"),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text("ADD NEW PRODUCT", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddProductDialog(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(productNotifierProvider.notifier).fetchProducts();
              ref.invalidate(dashboardMetricsProvider);
            },
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error loading dashboard data: $err")),
        data: (products) {
          int lowStockAlerts = 0;
          int outOfStockCount = 0;

          List<String> lowStockNames = [];
          List<String> outOfStockNames = [];

          for (var p in products) {
            if (p.stockQuantity <= 0) {
              outOfStockCount++;
              outOfStockNames.add(p.name.toUpperCase());
            } else if (p.stockQuantity <= p.reorderLevel) {
              lowStockAlerts++;
              lowStockNames.add("${p.name.toUpperCase()} (${p.stockQuantity} Pcs left)");
            }
          }

          final filteredProducts = products.where((p) {
            final matchName = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchSku = p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchName || matchSku;
          }).toList();

          return metricsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error loading live metrics: $err")),
            data: (metrics) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: FINANCIAL PERFORMANCE SUMMARY CARDS
                    const Text("Financial Performance Analytics",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildAnalyticsCard("Today's Revenue", "KES ${metrics.todayRevenue.toStringAsFixed(1)}", Icons.today, Colors.blue),
                        const SizedBox(width: 14),
                        _buildAnalyticsCard("Weekly Revenue", "KES ${metrics.weeklyRevenue.toStringAsFixed(1)}", Icons.view_week, Colors.indigo),
                        const SizedBox(width: 14),
                        _buildAnalyticsCard("Monthly Revenue", "KES ${metrics.monthlyRevenue.toStringAsFixed(1)}", Icons.calendar_month, Colors.purple),
                        const SizedBox(width: 14),
                        _buildAnalyticsCard("Gross Profit Margin", "KES ${metrics.grossProfit.toStringAsFixed(1)}", Icons.trending_up, Colors.teal),
                        const SizedBox(width: 14),
                        _buildAnalyticsCard("Net Store Profit", "KES ${metrics.grossProfit.toStringAsFixed(1)}", Icons.monetization_on, Colors.green),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // SECTION 2: LIVE STOCK ALERT INSIGHTS
                    const Text("Critical Stock Alerts",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatusAlertPanel("Out of Stock Alerts ($outOfStockCount)", outOfStockNames, Colors.red),
                        const SizedBox(width: 16),
                        _buildStatusAlertPanel("Low Stock Warnings ($lowStockAlerts)", lowStockNames, Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // SECTION 3: RECENT TRANSACTIONS & PERFORMANCE METRICS MATRIX
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Recent Completed Transactions",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              const SizedBox(height: 10),
                              _buildRecentTransactionsTable(metrics.recentSales),
                              const SizedBox(height: 24),
                              const Text("Top Performing Products (Velocity)",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              const SizedBox(height: 10),
                              _buildTopProductsGrid(metrics.topProducts),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Active Shift Cashiers",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              const SizedBox(height: 10),
                              _buildActiveCashiersList(metrics.activeCashiers),
                              const SizedBox(height: 24),
                              const Text("Valued Top Accounts / Customers",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              const SizedBox(height: 10),
                              _buildTopCustomersList(metrics.topCustomers),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // SECTION 4: MASTER INVENTORY TABLE
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text("Master Product Stock Registry",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search stock by item name or SKU reference code...",
                        prefixIcon: const Icon(Icons.search),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: filteredProducts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(child: Text("No items match your search queries.")),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                              columns: const [
                                DataColumn(label: Text("SKU Code", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Product Title Name", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Cost Price", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Selling Price", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Stock Level", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Status Badge", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredProducts.map((p) {
                                return DataRow(cells: [
                                  DataCell(Text(p.sku)),
                                  DataCell(Text(p.name.toUpperCase())),
                                  DataCell(Text("KES ${p.costPrice.toStringAsFixed(1)}")),
                                  DataCell(Text("KES ${p.sellingPrice.toStringAsFixed(1)}")),
                                  DataCell(Text("${p.stockQuantity} ${p.unitOfMeasure}")),
                                  DataCell(_buildStatusBadge(p.stockQuantity, p.reorderLevel)),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.blueGrey[600], size: 20),
                                        tooltip: "Edit product",
                                        onPressed: () => _showEditProductDialog(context, p),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                                        tooltip: "Delete product",
                                        onPressed: () => _confirmDeleteProduct(context, p),
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.grey[200]!, blurRadius: 4, offset: const Offset(0, 2))],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 22,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAlertPanel(String header, List<String> items, Color color) {
    return Expanded(
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(header, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(height: 12),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text("All operational stocks stable.", style: TextStyle(color: Colors.grey[500], fontSize: 12)))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_right, size: 16, color: color),
                            Text(items[index],
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsTable(List<Sale> sales) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
      child: sales.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text("No transactions recorded yet.")),
            )
          : ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: sales.map(_buildTransactionRow).toList(),
            ),
    );
  }

  Widget _buildTransactionRow(Sale sale) {
    return ListTile(
      leading: Icon(Icons.receipt_long, color: Colors.blueGrey[400]),
      title: Text("TXN-${sale.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text("Cashier #${sale.cashierId} • ${_timeAgo(sale.timestamp)}", style: const TextStyle(fontSize: 12)),
      trailing: Text(
        "KES ${sale.totalAmount.toStringAsFixed(1)}",
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    if (diff.inHours < 24) return "${diff.inHours} hr${diff.inHours > 1 ? 's' : ''} ago";
    return "${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago";
  }

  Widget _buildTopProductsGrid(List<ProductRanking> topProducts) {
    if (topProducts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey[200]!)),
        child: Center(child: Text("No sales velocity data yet.", style: TextStyle(color: Colors.grey[500]))),
      );
    }

    const rankColors = [Colors.amber, Colors.grey, Colors.brown];
    final children = <Widget>[];
    for (int i = 0; i < topProducts.length; i++) {
      final p = topProducts[i];
      children.add(_buildProductRankCard(
        p.name.toUpperCase(),
        "${p.quantitySold} Pcs Sold",
        "Rank #${i + 1}",
        rankColors[i % rankColors.length],
      ));
      if (i < topProducts.length - 1) children.add(const SizedBox(width: 10));
    }
    return Row(children: children);
  }

  Widget _buildProductRankCard(String name, String volume, String rank, Color rankColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              label: Text(rank, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: rankColor,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(volume, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCashiersList(List<User> activeCashiers) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
      child: activeCashiers.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text("No cashiers currently on shift.")),
            )
          : Column(children: activeCashiers.map(_buildCashierRow).toList()),
    );
  }

  Widget _buildCashierRow(User user) {
    final displayName = user.username;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueGrey[100],
        child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : "?"),
      ),
      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text("Branch #${user.branchId}", style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle))),
          SizedBox(width: 6),
          Text("Active", style: TextStyle(fontSize: 12, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildTopCustomersList(List<CustomerRanking> topCustomers) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
      child: topCustomers.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text("No customer purchase history yet.")),
            )
          : Column(children: topCustomers.map(_buildCustomerRow).toList()),
    );
  }

  Widget _buildCustomerRow(CustomerRanking customer) {
    return ListTile(
      leading: const Icon(Icons.star, color: Colors.orangeAccent),
      title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      trailing: Text("KES ${customer.totalSpent.toStringAsFixed(0)} Volume",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
    );
  }

  Widget _buildStatusBadge(int stock, int reorder) {
    String label = "Good Stock";
    Color bg = Colors.green[50]!;
    Color text = Colors.green[700]!;

    if (stock <= 0) {
      label = "Out of Stock";
      bg = Colors.red[50]!;
      text = Colors.red[700]!;
    } else if (stock <= reorder) {
      label = "Low Stock Warning";
      bg = Colors.orange[50]!;
      text = Colors.orange[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class AddProductDialogForm extends ConsumerStatefulWidget {
  const AddProductDialogForm({super.key});

  @override
  ConsumerState<AddProductDialogForm> createState() => _AddProductDialogFormState();
}

class _AddProductDialogFormState extends ConsumerState<AddProductDialogForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _costController = TextEditingController();
  final _sellingController = TextEditingController();
  final _stockController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Register New Product Item"),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Product Name", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(labelText: "Unique SKU Reference Code", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? "SKU code is required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(labelText: "Cost Price (Buying Price)", border: OutlineInputBorder(), prefixText: "KES "),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null ? "Enter a valid cost price number" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sellingController,
                  decoration: const InputDecoration(labelText: "Selling Price (Retail Price)", border: OutlineInputBorder(), prefixText: "KES "),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null ? "Enter a valid retail selling price number" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: "Initial Opening Stock Quantity", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v ?? '') == null ? "Enter a valid stock integer figure" : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final database = ref.read(databaseProvider);
              try {
                await database.customStatement(
                  'INSERT INTO products (sku, name, cost_price, selling_price, stock_quantity, reorder_level, unit_of_measure, branch_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                  [
                    _skuController.text.trim(),
                    _nameController.text.trim(),
                    double.parse(_costController.text),
                    double.parse(_sellingController.text),
                    int.parse(_stockController.text),
                    10,
                    'Pcs',
                    1,
                  ],
                );
                ref.read(productNotifierProvider.notifier).fetchProducts();
                ref.invalidate(dashboardMetricsProvider);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("New product successfully registered into database layout system!")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Database Insertion Error (Check for Duplicate SKU Codes): $e")),
                );
              }
            }
          },
          child: const Text("SAVE AND REGISTER", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Pre-filled form for editing an existing product's details.
class EditProductDialogForm extends ConsumerStatefulWidget {
  final LocalProduct product;

  const EditProductDialogForm({super.key, required this.product});

  @override
  ConsumerState<EditProductDialogForm> createState() => _EditProductDialogFormState();
}

class _EditProductDialogFormState extends ConsumerState<EditProductDialogForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _costController;
  late final TextEditingController _sellingController;
  late final TextEditingController _stockController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _skuController = TextEditingController(text: p.sku);
    _costController = TextEditingController(text: p.costPrice.toString());
    _sellingController = TextEditingController(text: p.sellingPrice.toString());
    _stockController = TextEditingController(text: p.stockQuantity.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(productNotifierProvider.notifier).updateProduct(
            id: widget.product.id,
            name: _nameController.text.trim(),
            sku: _skuController.text.trim(),
            costPrice: double.parse(_costController.text),
            sellingPrice: double.parse(_sellingController.text),
            stockQuantity: int.parse(_stockController.text),
          );
      ref.invalidate(dashboardMetricsProvider);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product updated successfully.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update Error (Check for Duplicate SKU Codes): $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Product"),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Product Name", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(labelText: "Unique SKU Reference Code", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? "SKU code is required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(labelText: "Cost Price (Buying Price)", border: OutlineInputBorder(), prefixText: "KES "),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null ? "Enter a valid cost price number" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sellingController,
                  decoration: const InputDecoration(labelText: "Selling Price (Retail Price)", border: OutlineInputBorder(), prefixText: "KES "),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null ? "Enter a valid retail selling price number" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: "Stock Quantity", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v ?? '') == null ? "Enter a valid stock integer figure" : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}