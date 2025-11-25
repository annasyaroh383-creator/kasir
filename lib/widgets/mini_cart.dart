import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir/providers/cart_provider.dart';

class MiniCart extends StatelessWidget {
  const MiniCart({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final items = cart.items;
        final subtotal = cart.subtotal;
        final taxAmount = cart.taxAmount;
        final total = cart.total;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Keranjang Belanja',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (items.isNotEmpty)
                    IconButton(
                      onPressed: () => cart.clearCart(),
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Kosongkan Keranjang',
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Cart Items
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'Keranjang kosong\nTambahkan produk untuk memulai',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Product Image
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          item.product.imageUrl ??
                                              'https://via.placeholder.com/40x40/cccccc/666666?text=No+Img',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Rp ${item.product.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity Controls
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () => cart.updateQuantity(
                                          item.product.id,
                                          item.quantity - 1,
                                        ),
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 16,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      SizedBox(
                                        width: 30,
                                        child: Text(
                                          item.quantity.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => cart.updateQuantity(
                                          item.product.id,
                                          item.quantity + 1,
                                        ),
                                        icon: const Icon(Icons.add, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),

                                  // Remove Button
                                  IconButton(
                                    onPressed: () =>
                                        cart.removeProduct(item.product.id),
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Totals
              if (items.isNotEmpty) ...[
                const Divider(),
                _buildTotalRow('Subtotal', subtotal),
                _buildTotalRow('PPN (10%)', taxAmount),
                const Divider(),
                _buildTotalRow('Total', total, isBold: true),
                const SizedBox(height: 16),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/checkout'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Checkout'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Rp ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
