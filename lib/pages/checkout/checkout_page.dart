import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kasir/providers/cart_provider.dart';
import 'package:kasir/services/auth_service.dart';
import 'package:kasir/services/printer_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _selectedPaymentMethod = 'cash';
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'cash', 'name': 'Tunai', 'icon': Icons.payments},
    {'id': 'qris', 'name': 'QRIS', 'icon': Icons.qr_code},
    {'id': 'e_money', 'name': 'E-Money', 'icon': Icons.account_balance_wallet},
    {'id': 'card', 'name': 'Kartu Kredit/Debit', 'icon': Icons.credit_card},
  ];

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      final cart = context.read<CartProvider>();
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      // Prepare sale data
      final saleData = {
        'customer_id': _customerNameController.text.isNotEmpty
            ? null
            : null, // TODO: Create customer if needed
        'items': cart.items
            .map(
              (item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
                'unit_price': item.product.price,
                'discount': 0, // TODO: Add discount logic
              },
            )
            .toList(),
        'discount_amount': 0, // TODO: Add discount logic
        'tax_amount': cart.taxAmount,
        'notes': 'POS Transaction',
      };

      // Create sale via API
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/sales'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(saleData),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create sale: ${response.body}');
      }

      final saleResponse = jsonDecode(response.body);
      final saleId = saleResponse['data']['id'];

      // Process payment
      final paymentResponse = await http.post(
        Uri.parse('${AuthService.baseUrl}/sales/$saleId/payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'method': _selectedPaymentMethod,
          'amount': cart.total,
        }),
      );

      if (paymentResponse.statusCode != 200) {
        throw Exception('Payment failed: ${paymentResponse.body}');
      }

      // Get receipt data
      final receiptResponse = await http.get(
        Uri.parse('${AuthService.baseUrl}/sales/$saleId/receipt'),
        headers: {'Authorization': 'Bearer $token'},
      );

      bool printSuccess = false;
      if (receiptResponse.statusCode == 200) {
        final receiptData = jsonDecode(receiptResponse.body)['data'];

        // Try to print receipt automatically
        final printerService = PrinterService();
        printSuccess = await printerService.printReceipt(receiptData);
      }

      if (mounted) {
        setState(() => _isProcessing = false);

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Pembayaran Berhasil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                Text(
                  'Invoice: ${saleResponse['data']['invoice_code'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: Rp ${cart.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Metode: ${_paymentMethods.firstWhere((m) => m['id'] == _selectedPaymentMethod, orElse: () => {'name': 'Unknown'})['name']}',
                ),
                const SizedBox(height: 8),
                Text(
                  printSuccess
                      ? 'Struk telah dicetak'
                      : 'Printer tidak terhubung',
                  style: TextStyle(
                    color: printSuccess ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  cart.clearCart();
                  context.go('/dashboard');
                },
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cart.items.isEmpty
          ? const Center(child: Text('Keranjang kosong'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ringkasan Pesanan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...cart.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.product.name} x${item.quantity}',
                                    ),
                                  ),
                                  Text(
                                    'Rp ${item.subtotal.toStringAsFixed(0)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          _buildTotalRow('Subtotal', cart.subtotal),
                          _buildTotalRow('PPN (10%)', cart.taxAmount),
                          const Divider(),
                          _buildTotalRow('Total', cart.total, isBold: true),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Customer Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Pelanggan (Opsional)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customerNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Pelanggan',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customerPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Nomor Telepon',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Methods
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Metode Pembayaran',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._paymentMethods.map(
                            (method) => RadioListTile<String>(
                              title: Row(
                                children: [
                                  Icon(
                                    method['icon'] as IconData? ??
                                        Icons.payment,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(method['name'] as String? ?? 'Unknown'),
                                ],
                              ),
                              value: method['id'] as String? ?? '',
                              groupValue: _selectedPaymentMethod,
                              onChanged: (value) {
                                if (value != null && value.isNotEmpty) {
                                  setState(
                                    () => _selectedPaymentMethod = value,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Process Payment Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Bayar Rp ${cart.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ],
              ),
            ),
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
