import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  double _taxRate = 0.1; // 10% tax
  double _discount = 0.0;

  List<CartItem> get items => _items;
  double get taxRate => _taxRate;
  double get discount => _discount;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  double get taxAmount => subtotal * _taxRate;

  double get total => subtotal + taxAmount - _discount;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  void addProduct(Product product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + quantity,
      );
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void addItem(Product product, {int quantity = 1}) {
    addProduct(product, quantity: quantity);
  }

  double getTotal() {
    return total;
  }

  void removeProduct(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
      notifyListeners();
    }
  }

  void updateDiscount(int productId, double discount) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(discount: discount);
      notifyListeners();
    }
  }

  void setGlobalDiscount(double discount) {
    _discount = discount;
    notifyListeners();
  }

  void setTaxRate(double rate) {
    _taxRate = rate;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _discount = 0.0;
    notifyListeners();
  }

  bool isInCart(int productId) {
    return _items.any((item) => item.product.id == productId);
  }

  CartItem? getCartItem(int productId) {
    try {
      return _items.firstWhere((item) => item.product.id == productId);
    } catch (e) {
      return null;
    }
  }
}
