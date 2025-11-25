import 'package:go_router/go_router.dart';
import 'package:kasir/pages/auth/login_page.dart';
import 'package:kasir/pages/pos/dashboard_page.dart';
import 'package:kasir/pages/pos/scan_barcode_page.dart';
import 'package:kasir/pages/cart/cart_page.dart';
import 'package:kasir/pages/checkout/checkout_page.dart';
import 'package:kasir/pages/printer/printer_setup_page.dart';
import 'package:kasir/pages/products/product_management_page.dart';

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
        path: '/printer-setup',
        builder: (context, state) => const PrinterSetupPage(),
      ),
      GoRoute(
        path: '/product-management',
        builder: (context, state) => const ProductManagementPage(),
      ),
    ],
  );
}
