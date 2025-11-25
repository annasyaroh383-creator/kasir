import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir/data/dummy_data.dart';
import 'package:kasir/models/product.dart';
import 'package:provider/provider.dart';
import 'package:kasir/providers/cart_provider.dart';

class ScanBarcodePage extends StatefulWidget {
  const ScanBarcodePage({super.key});

  @override
  State<ScanBarcodePage> createState() => _ScanBarcodePageState();
}

class _ScanBarcodePageState extends State<ScanBarcodePage> {
  final TextEditingController _barcodeController = TextEditingController();
  bool _isScanning = false;
  Product? _foundProduct;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    setState(() => _isScanning = true);

    // Simulate scanning delay
    await Future.delayed(const Duration(seconds: 2));

    // For demo, use a random barcode from dummy data
    final randomProduct =
        DummyData.products[DateTime.now().millisecondsSinceEpoch %
            DummyData.products.length];
    final barcode = randomProduct.barcode;

    setState(() {
      _isScanning = false;
      _barcodeController.text = barcode;
      _foundProduct = DummyData.findProductByBarcode(barcode);
    });
  }

  void _manualSearch() {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final product = DummyData.findProductByBarcode(barcode);
    setState(() => _foundProduct = product);
  }

  void _addToCart() {
    if (_foundProduct != null) {
      context.read<CartProvider>().addItem(_foundProduct!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_foundProduct!.name} ditambahkan ke keranjang'),
          duration: const Duration(seconds: 2),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            onPressed: _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Camera Preview Area (Simulated)
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isScanning
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Scanning...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 80,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Point camera at barcode',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Manual Input
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode Number',
                hintText: 'Enter barcode manually',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  onPressed: _manualSearch,
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _manualSearch(),
            ),

            const SizedBox(height: 24),

            // Product Result
            if (_foundProduct != null) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child:
                            _foundProduct!.imageUrl != null &&
                                _foundProduct!.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _foundProduct!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPlaceholderIcon(),
                                ),
                              )
                            : _buildPlaceholderIcon(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foundProduct!.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Rp ${_foundProduct!.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Stok: ${_foundProduct!.stockQuantity}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _addToCart,
                        child: const Text('Tambah'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_barcodeController.text.isNotEmpty) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Produk tidak ditemukan',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return const Icon(Icons.inventory_2, color: Colors.grey, size: 30);
  }
}
