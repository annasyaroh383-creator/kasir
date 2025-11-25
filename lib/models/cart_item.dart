import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount;

  CartItem({required this.product, this.quantity = 1, this.discount = 0.0});

  double get subtotal => (product.price * quantity) - discount;

  double get unitPrice => product.price;

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'subtotal': subtotal,
    };
  }

  CartItem copyWith({Product? product, int? quantity, double? discount}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
    );
  }
}
