class Product {
  final int id;
  final String name;
  final String barcode;
  final int categoryId;
  final double price;
  final double costPrice;
  final int stockQuantity;
  final int minStockLevel;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.categoryId,
    required this.price,
    required this.costPrice,
    required this.stockQuantity,
    required this.minStockLevel,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      barcode: json['barcode'],
      categoryId: json['category_id'],
      price: double.parse(json['price'].toString()),
      costPrice: double.parse(json['cost_price'].toString()),
      stockQuantity: json['stock_quantity'],
      minStockLevel: json['min_stock_level'],
      description: json['description'],
      imageUrl: json['image_url'],
      isActive: json['is_active'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'category_id': categoryId,
      'price': price,
      'cost_price': costPrice,
      'stock_quantity': stockQuantity,
      'min_stock_level': minStockLevel,
      'description': description,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
