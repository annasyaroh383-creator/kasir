import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kasir/services/auth_service.dart';

class PaymentService {
  static const String baseUrl = AuthService.baseUrl;

  /// Check payment status by invoice ID
  static Future<String> checkPaymentStatus(String invoiceId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No auth token');

      // TEMPORARY: Mock payment status check for testing without backend
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate network delay

      // Simulate payment completion after a few checks
      final random = DateTime.now().millisecondsSinceEpoch % 10;
      if (random > 6) {
        return 'COMPLETED'; // Simulate successful payment
      } else if (random > 3) {
        return 'PENDING'; // Still processing
      } else {
        return 'FAILED'; // Payment failed
      }

      /* ORIGINAL BACKEND CODE - Uncomment when PHP/Laravel is installed
      final response = await http.get(
        Uri.parse('$baseUrl/payments/status?invoice_id=$invoiceId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['data']['status'] ?? 'PENDING';
        }
      }

      throw Exception('Failed to check payment status');
      */
    } catch (e) {
      throw Exception('Payment status check failed: $e');
    }
  }

  /// Process payment after successful QR payment
  static Future<Map<String, dynamic>> processPayment({
    required String invoiceId,
    required String paymentToken,
    required String method,
    required double amount,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No auth token');

      // TEMPORARY: Mock payment processing for testing without backend
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate processing delay

      // Mock successful payment processing
      return {
        'success': true,
        'message': 'Payment processed successfully',
        'data': {
          'transaction_id':
              'TXN_' + DateTime.now().millisecondsSinceEpoch.toString(),
          'invoice_id': invoiceId,
          'amount': amount,
          'method': method,
          'status': 'completed',
          'processed_at': DateTime.now().toIso8601String(),
        },
      };

      /* ORIGINAL BACKEND CODE - Uncomment when PHP/Laravel is installed
      final response = await http.post(
        Uri.parse('$baseUrl/payments/process'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'invoice_id': invoiceId,
          'payment_token': paymentToken,
          'method': method,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? '',
          'data': data['data'],
        };
      }

      return {'success': false, 'message': 'Payment processing failed'};
      */
    } catch (e) {
      return {'success': false, 'message': 'Payment processing error: $e'};
    }
  }

  /// Initiate QR payment (get QR string)
  static Future<Map<String, dynamic>> initiateQrPayment({
    required String method,
    required double amount,
    required String invoiceId,
  }) async {
    try {
      final token = await AuthService.getToken();
      print(
        'DEBUG: Retrieved token: ${token != null ? "Token exists (${token.length} chars)" : "NULL"}',
      );

      if (token == null) throw Exception('No auth token');

      final requestBody = jsonEncode({
        'method': method,
        'amount': amount,
        'invoice_id': invoiceId,
      });

      print('DEBUG: QR Payment Request - URL: $baseUrl/payments/initiate-qr');
      print(
        'DEBUG: QR Payment Request - Headers: Authorization: Bearer ${token.substring(0, 20)}...',
      );
      print('DEBUG: QR Payment Request - Body: $requestBody');

      // TEMPORARY: Mock QR payment initiation for testing without backend
      // Remove this when Laravel backend is running
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network delay

      // Generate mock QR string (simulating QRIS format)
      final mockQrString =
          '00020101021126660014ID.CO.QRIS.WWW0215ID20200123456780303UME51440014ID.CO.QRIS.WWW0215ID20200123456780303UME5204541153033605404${amount.toStringAsFixed(0)}5802ID5919MOCK MERCHANT TEST6009JAKARTA61051234562150111MOCKTERMINAL6304${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final mockPaymentToken =
          'qr_token_' + DateTime.now().millisecondsSinceEpoch.toString();
      final mockExpiresAt = DateTime.now()
          .add(const Duration(minutes: 5))
          .toIso8601String();

      print('DEBUG: Mock QR Payment Response - Success');
      print(
        'DEBUG: Mock QR String generated: ${mockQrString.substring(0, 50)}...',
      );

      return {
        'success': true,
        'qr_string': mockQrString,
        'payment_token': mockPaymentToken,
        'expires_at': mockExpiresAt,
      };

      /* ORIGINAL BACKEND CODE - Uncomment when PHP/Laravel is installed
      final response = await http.post(
        Uri.parse('$baseUrl/payments/initiate-qr'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      print('DEBUG: QR Payment Response - Status: ${response.statusCode}');
      print('DEBUG: QR Payment Response - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'success': true,
            'qr_string': data['data']['qr_string'],
            'payment_token': data['data']['payment_token'],
            'expires_at': data['data']['expires_at'],
          };
        }
      }

      return {'success': false, 'message': 'Failed to initiate QR payment'};
      */
    } catch (e) {
      print('DEBUG: QR Payment Error: $e');
      return {'success': false, 'message': 'QR payment initiation error: $e'};
    }
  }

  /// Process direct payment (cash/card)
  static Future<Map<String, dynamic>> processDirectPayment({
    required List<Map<String, dynamic>> items,
    required String method,
    required double amount,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No auth token');

      // TEMPORARY: Mock direct payment processing for testing without backend
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate processing delay

      // Mock successful direct payment
      return {
        'success': true,
        'message': 'Direct payment processed successfully',
        'data': {
          'transaction_id':
              'TXN_' + DateTime.now().millisecondsSinceEpoch.toString(),
          'invoice_id':
              'INV_' + DateTime.now().millisecondsSinceEpoch.toString(),
          'amount': amount,
          'method': method,
          'customer_id': customerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'notes': notes,
          'items': items,
          'status': 'completed',
          'processed_at': DateTime.now().toIso8601String(),
        },
      };

      /* ORIGINAL BACKEND CODE - Uncomment when PHP/Laravel is installed
      final response = await http.post(
        Uri.parse('$baseUrl/payments/direct'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'items': items,
          'method': method,
          'amount': amount,
          'customer_id': customerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? '',
          'data': data['data'],
        };
      }

      return {'success': false, 'message': 'Direct payment failed'};
      */
    } catch (e) {
      return {'success': false, 'message': 'Direct payment error: $e'};
    }
  }

  /// Validate payment token to prevent double payment
  static Future<bool> validatePaymentToken(String paymentToken) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      // TEMPORARY: Mock token validation for testing without backend
      await Future.delayed(
        const Duration(milliseconds: 200),
      ); // Simulate network delay

      // Mock validation - assume token is valid if it starts with 'qr_token_'
      return paymentToken.startsWith('qr_token_');

      /* ORIGINAL BACKEND CODE - Uncomment when PHP/Laravel is installed
      final response = await http.post(
        Uri.parse('$baseUrl/payments/validate-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'payment_token': paymentToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }

      return false;
      */
    } catch (e) {
      return false;
    }
  }
}
