import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/app_database.dart';
import '../providers/inventory_dashboard_provider.dart';

// Clean extraction: Read products directly from the database reactively
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.read(databaseProvider);
  return (db.select(db.products)).watch();
});

class StockEntryScreen extends ConsumerStatefulWidget {
  const StockEntryScreen({super.key});

  @override
  ConsumerState<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends ConsumerState<StockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  String _movementType = 'Stock In';
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the standalone provider safely
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("STOCK ENTRY & ADJUSTMENTS")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text("Database Sync Error: $e", style: const TextStyle(color: Colors.red)),
                data: (products) => DropdownButtonFormField<Product>(
                  decoration: const InputDecoration(labelText: "Select Product", border: OutlineInputBorder()),
                  value: _selectedProduct,
                  items: products
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text("${p.name} (Current Stock: ${p.stockQuantity})"),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedProduct = v),
                  validator: (v) => v == null ? "Please select a product" : null,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Movement Type", border: OutlineInputBorder()),
                value: _movementType,
                items: const [
                  DropdownMenuItem(value: 'Stock In', child: Text('Stock In')),
                  DropdownMenuItem(value: 'Stock Out', child: Text('Stock Out')),
                  DropdownMenuItem(value: 'Adjustment', child: Text('Adjustment')),
                ],
                onChanged: (v) => setState(() => _movementType = v!),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: "Quantity", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter quantity";
                  if (int.tryParse(v) == null) return "Enter a valid whole number";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: "Reason / Remarks", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueGrey[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate() && _selectedProduct != null) {
                    final db = ref.read(databaseProvider);
                    final qty = int.parse(_quantityController.text);

                    // Fire database update query execution
                    await db.updateStock(_selectedProduct!.id, qty, _movementType);

                    // Clean fields on success entry
                    _quantityController.clear();
                    _reasonController.clear();
                    setState(() {
                      _selectedProduct = null;
                    });

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Stock Registry updated successfully!")),
                    );
                    
                    // Invalidate the dashboard metrics to refresh
                    ref.invalidate(dashboardMetricsProvider);
                  }
                },
                child: const Text("POST MOVEMENT", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}