import 'package:go_router/go_router.dart';
import 'package:kasir/pages/auth/login_page.dart';
import 'package:kasir/pages/pos/dashboard_page.dart';
import 'package:kasir/pages/pos/scan_barcode_page.dart';
import 'package:kasir/pages/cart/cart_page.dart';
import 'package:kasir/pages/checkout/checkout_page.dart';
import 'package:kasir/pages/payment/qr_payment_page.dart';
import 'package:kasir/pages/printer/printer_setup_page.dart';
import 'package:kasir/pages/products/product_management_page.dart';
import 'package:kasir/pages/reports/sales_reports_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/scan-barcode',
        builder: (context, state) => const ScanBarcodePage(),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: '/qr-payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return QrPaymentPage(
            paymentMethod: extra['paymentMethod'] ?? 'QRIS',
            qrString: extra['qrString'] ?? '',
            totalAmount: extra['totalAmount'] ?? 0.0,
            invoiceId: extra['invoiceId'] ?? '',
            paymentToken: extra['paymentToken'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/printer-setup',
        builder: (context, state) => const PrinterSetupPage(),
      ),
      GoRoute(
        path: '/product-management',
        builder: (context, state) => const ProductManagementPage(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const SalesReportsPage(),
      ),
    ],
  );
}
