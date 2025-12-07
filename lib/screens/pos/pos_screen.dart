import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kasir/providers/auth_provider.dart';
import 'package:kasir/providers/cart_provider.dart';
import 'package:kasir/models/product.dart';
import 'package:intl/intl.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isScanning = false;
  // TODO: Implement category filtering
  // ignore: unused_field
  final String _selectedCategory = 'All';

  // Sample products for demo
  final List<Product> _sampleProducts = [
    Product(
      id: 1,
      name: 'Indomie Goreng',
      barcode: '8996001600012',
      categoryId: 1,
      price: 3500,
      costPrice: 2800,
      stockQuantity: 50,
      minStockLevel: 10,
      description: 'Indomie Goreng Original',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 2,
      name: 'Coca Cola 600ml',
      barcode: '8996001440019',
      categoryId: 2,
      price: 5000,
      costPrice: 4000,
      stockQuantity: 30,
      minStockLevel: 5,
      description: 'Coca Cola Botol 600ml',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 3,
      name: 'Beras Ramos 5kg',
      barcode: '8996001440020',
      categoryId: 3,
      price: 75000,
      costPrice: 65000,
      stockQuantity: 15,
      minStockLevel: 3,
      description: 'Beras Ramos Premium 5kg',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _barcodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addProductToCart(Product product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} ditambahkan ke keranjang')),
    );
  }

  void _scanBarcode() async {
    setState(() => _isScanning = true);

    // Simulate barcode scanning
    await Future.delayed(const Duration(seconds: 2));

    // For demo, randomly select a product
    final randomProduct =
        _sampleProducts[DateTime.now().millisecondsSinceEpoch %
            _sampleProducts.length];
    _barcodeController.text = randomProduct.barcode;

    setState(() => _isScanning = false);

    // Find and add product
    final product = _sampleProducts.firstWhere(
      (p) => p.barcode == randomProduct.barcode,
      orElse: () => _sampleProducts.first,
    );
    _addProductToCart(product);
  }

  void _showPaymentDialog() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Keranjang kosong')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        total: cartProvider.total,
        onPaymentComplete: () {
          cartProvider.clearCart();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pembayaran berhasil!')));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Cashier'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart), text: 'POS'),
            Tab(icon: Icon(Icons.inventory), text: 'Produk'),
            Tab(icon: Icon(Icons.receipt), text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPosTab(cartProvider),
          _buildProductsTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPaymentDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.payment),
      ),
    );
  }

  Widget _buildPosTab(CartProvider cartProvider) {
    return Row(
      children: [
        // Left side - Products
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Barcode scanner
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                        onSubmitted: (value) {
                          // Find product by barcode
                          final product = _sampleProducts.firstWhere(
                            (p) => p.barcode == value,
                            orElse: () => _sampleProducts.first,
                          );
                          if (product.barcode == value) {
                            _addProductToCart(product);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isScanning ? null : _scanBarcode,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan'),
                    ),
                  ],
                ),
              ),

              // Product grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _sampleProducts.length,
                  itemBuilder: (context, index) {
                    final product = _sampleProducts[index];
                    return Card(
                      elevation: 4,
                      child: InkWell(
                        onTap: () => _addProductToCart(product),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inventory,
                                size: 48,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${NumberFormat('#,###').format(product.price)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Stok: ${product.stockQuantity}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Right side - Cart
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.grey[100],
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: const Text(
                    'Keranjang Belanja',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),

                // Cart items
                Expanded(
                  child: cartProvider.items.isEmpty
                      ? const Center(child: Text('Keranjang kosong'))
                      : ListView.builder(
                          itemCount: cartProvider.items.length,
                          itemBuilder: (context, index) {
                            final item = cartProvider.items[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                title: Text(item.product.name),
                                subtitle: Text(
                                  'Rp ${NumberFormat('#,###').format(item.product.price)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        if (item.quantity > 1) {
                                          cartProvider.updateQuantity(
                                            item.product.id,
                                            item.quantity - 1,
                                          );
                                        }
                                      },
                                    ),
                                    Text('${item.quantity}'),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        cartProvider.updateQuantity(
                                          item.product.id,
                                          item.quantity + 1,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        cartProvider.removeProduct(
                                          item.product.id,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Total section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text(
                            'Rp ${NumberFormat('#,###').format(cartProvider.subtotal)}',
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('PPN (10%):'),
                          Text(
                            'Rp ${NumberFormat('#,###').format(cartProvider.taxAmount)}',
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rp ${NumberFormat('#,###').format(cartProvider.total)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: cartProvider.items.isEmpty
                              ? null
                              : _showPaymentDialog,
                          icon: const Icon(Icons.payment),
                          label: const Text('Bayar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab() {
    return const Center(child: Text('Manajemen Produk - Coming Soon'));
  }

  Widget _buildHistoryTab() {
    return const Center(child: Text('Riwayat Penjualan - Coming Soon'));
  }
}

class PaymentDialog extends StatefulWidget {
  final double total;
  final VoidCallback onPaymentComplete;

  const PaymentDialog({
    super.key,
    required this.total,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _paymentMethod = 'cash';
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.total.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final receivedAmount = double.tryParse(_amountController.text) ?? 0;
    final change = receivedAmount - widget.total;

    return AlertDialog(
      title: const Text('Pembayaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total: Rp ${NumberFormat('#,###').format(widget.total)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Payment method
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Metode Pembayaran'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Tunai')),
              DropdownMenuItem(value: 'qris', child: Text('QRIS')),
              DropdownMenuItem(value: 'e_money', child: Text('E-Money')),
              DropdownMenuItem(value: 'card', child: Text('Kartu')),
            ],
            onChanged: (value) {
              setState(() => _paymentMethod = value!);
            },
          ),

          const SizedBox(height: 16),

          // Amount received (for cash)
          if (_paymentMethod == 'cash') ...[
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Jumlah Diterima',
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Kembalian: Rp ${NumberFormat('#,###').format(change > 0 ? change : 0)}',
              style: TextStyle(
                color: change >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: receivedAmount >= widget.total || _paymentMethod != 'cash'
              ? widget.onPaymentComplete
              : null,
          child: const Text('Konfirmasi'),
        ),
      ],
    );
  }
}
