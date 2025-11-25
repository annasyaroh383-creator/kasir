import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kasir/data/dummy_data.dart';
import 'package:kasir/models/product.dart';
import 'package:kasir/providers/cart_provider.dart';
import 'package:kasir/widgets/product_card.dart';
import 'package:kasir/widgets/mini_cart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = DummyData.products;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = DummyData.searchProducts(query);
      if (_selectedCategory != 'All') {
        _filteredProducts = _filteredProducts
            .where(
              (product) =>
                  product.categoryId ==
                  DummyData.categories.indexOf(_selectedCategory) + 1,
            )
            .toList();
      }
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filterProducts();
    });
  }

  void _scanBarcode() {
    context.push('/scan-barcode');
  }

  void _showRecommendations() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Rekomendasi Produk',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: DummyData.getRecommendedProducts().length,
                  itemBuilder: (context, index) {
                    final product = DummyData.getRecommendedProducts()[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(
                                product.imageUrl ??
                                    'https://via.placeholder.com/150x150/cccccc/666666?text=No+Image',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          'Rp ${product.price.toStringAsFixed(0)}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            context.read<CartProvider>().addItem(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.name} ditambahkan ke keranjang',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Tambah'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Cashier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
            tooltip: 'Scan Barcode',
          ),
          IconButton(
            icon: const Icon(Icons.recommend),
            onPressed: _showRecommendations,
            tooltip: 'Rekomendasi',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => context.push('/printer-setup'),
            tooltip: 'Printer Setup',
          ),
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () => context.push('/product-management'),
            tooltip: 'Kelola Produk',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          // Category Filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: _selectedCategory == 'All',
                  onSelected: (_) => _filterByCategory('All'),
                ),
                const SizedBox(width: 8),
                ...DummyData.categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) => _filterByCategory(category),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Products Grid and Cart
          Expanded(
            child: Row(
              children: [
                // Products Grid
                Expanded(
                  flex: isTablet ? 3 : 1,
                  child: _filteredProducts.isEmpty
                      ? const Center(child: Text('Tidak ada produk ditemukan'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isTablet ? 4 : 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return ProductCard(
                              product: product,
                              onTap: () {
                                context.read<CartProvider>().addItem(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${product.name} ditambahkan ke keranjang',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // Mini Cart (Tablet only)
                if (isTablet)
                  Container(
                    width: 350,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: const MiniCart(),
                  ),
              ],
            ),
          ),
        ],
      ),

      // Floating Action Button for Cart (Mobile)
      floatingActionButton: !isTablet
          ? Consumer<CartProvider>(
              builder: (context, cart, child) {
                final itemCount = cart.items.length;
                return Stack(
                  children: [
                    FloatingActionButton(
                      onPressed: () => context.push('/cart'),
                      child: const Icon(Icons.shopping_cart),
                    ),
                    if (itemCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          : null,

      // Bottom Navigation for Mobile
      bottomNavigationBar: !isTablet
          ? Consumer<CartProvider>(
              builder: (context, cart, child) {
                final total = cart.getTotal();
                if (total > 0) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Rp ${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => context.push('/checkout'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Checkout'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          : null,
    );
  }
}
