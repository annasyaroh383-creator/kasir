import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kasir/providers/cart_provider.dart';
import 'package:kasir/services/payment_service.dart';
import 'package:kasir/services/printer_service.dart';

class QrPaymentPage extends StatefulWidget {
  final String paymentMethod;
  final String qrString;
  final double totalAmount;
  final String invoiceId;
  final String paymentToken;

  const QrPaymentPage({
    super.key,
    required this.paymentMethod,
    required this.qrString,
    required this.totalAmount,
    required this.invoiceId,
    required this.paymentToken,
  });

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> {
  String _paymentStatus = 'Menunggu Pembayaran...';
  Timer? _pollingTimer;
  bool _isPolling = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isPolling) return;

      try {
        final status = await PaymentService.checkPaymentStatus(
          widget.invoiceId,
        );

        if (status == 'PAID') {
          _isPolling = false;
          _pollingTimer?.cancel();

          if (mounted) {
            setState(() => _paymentStatus = 'Pembayaran Berhasil');

            // Complete the transaction
            await _completeTransaction();

            // Show success dialog
            _showSuccessDialog();
          }
        } else if (status == 'FAILED' || status == 'EXPIRED') {
          _isPolling = false;
          _pollingTimer?.cancel();

          if (mounted) {
            setState(() => _paymentStatus = 'Pembayaran Gagal');

            // Show failure dialog
            _showFailureDialog();
          }
        }
        // Continue polling for other statuses
      } catch (e) {
        debugPrint('Polling error: $e');
        // Continue polling on error
      }
    });
  }

  Future<void> _completeTransaction() async {
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);

      // Process the sale and payment
      final result = await PaymentService.processPayment(
        invoiceId: widget.invoiceId,
        paymentToken: widget.paymentToken,
        method: widget.paymentMethod,
        amount: widget.totalAmount,
      );

      if (result['success']) {
        // Auto-print receipt
        await _printReceipt();

        // Clear cart
        cart.clearCart();
      }
    } catch (e) {
      debugPrint('Transaction completion error: $e');
    }
  }

  Future<void> _printReceipt() async {
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final printerService = PrinterService();

      final receiptData = {
        'store_name': 'Smart Cashier',
        'store_address': 'Jl. Example No. 123\nJakarta, Indonesia',
        'invoice_id': widget.invoiceId,
        'printed_at': DateTime.now().toString(),
        'customer_name': 'Pelanggan Umum',
        'customer_phone': null,
        'items': cart.items
            .map(
              (item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'unit_price': item.product.price,
                'subtotal': item.subtotal,
              },
            )
            .toList(),
        'subtotal': cart.subtotal,
        'tax_amount': cart.taxAmount,
        'final_total': widget.totalAmount,
        'payment_method': widget.paymentMethod,
        'paid_amount': widget.totalAmount,
      };

      await printerService.printReceipt(receiptData);
    } catch (e) {
      debugPrint('Auto-print failed: $e');
    }
  }

  void _showSuccessDialog() {
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
            Text('Invoice: ${widget.invoiceId}'),
            const SizedBox(height: 8),
            Text('Total: Rp ${widget.totalAmount.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text('Metode: ${widget.paymentMethod}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/dashboard');
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  void _showFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pembayaran Gagal'),
        content: const Text(
          'Pembayaran tidak dapat diproses. Silakan coba lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to checkout
            },
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }

  void _cancelPayment() {
    _isPolling = false;
    _pollingTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran QR'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: widget.qrString,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),

            const SizedBox(height: 24),

            // Payment Method
            Text(
              widget.paymentMethod,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            // Total Amount
            Text(
              'Rp ${widget.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 24),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(), color: _getStatusColor()),
                  const SizedBox(width: 8),
                  Text(
                    _paymentStatus,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            const Text(
              'Silakan scan QR code dengan aplikasi pembayaran Anda',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 32),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelPayment,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text(
                  'Batalkan',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_paymentStatus) {
      case 'Pembayaran Berhasil':
        return Colors.green;
      case 'Pembayaran Gagal':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    switch (_paymentStatus) {
      case 'Pembayaran Berhasil':
        return Icons.check_circle;
      case 'Pembayaran Gagal':
        return Icons.error;
      default:
        return Icons.hourglass_empty;
    }
  }
}
