import 'package:kasir/models/product.dart';

class DummyData {
  static List<Product> products = [
    Product(
      id: 1,
      name: 'Indomie Goreng',
      barcode: '8996001600012',
      categoryId: 1,
      price: 3500,
      costPrice: 2800,
      stockQuantity: 50,
      minStockLevel: 10,
      description: 'Indomie Goreng Original',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 2,
      name: 'Coca Cola 600ml',
      barcode: '8996001440019',
      categoryId: 2,
      price: 5000,
      costPrice: 4000,
      stockQuantity: 30,
      minStockLevel: 5,
      description: 'Coca Cola Botol 600ml',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 3,
      name: 'Beras Ramos 5kg',
      barcode: '8996001440020',
      categoryId: 3,
      price: 75000,
      costPrice: 65000,
      stockQuantity: 15,
      minStockLevel: 3,
      description: 'Beras Ramos Premium 5kg',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 4,
      name: 'Susu Ultra Milk 1L',
      barcode: '8996001440021',
      categoryId: 2,
      price: 18000,
      costPrice: 15000,
      stockQuantity: 25,
      minStockLevel: 5,
      description: 'Susu Ultra Milk Full Cream 1L',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 5,
      name: 'Roti Tawar Sari Roti',
      barcode: '8996001440022',
      categoryId: 4,
      price: 12000,
      costPrice: 10000,
      stockQuantity: 20,
      minStockLevel: 4,
      description: 'Roti Tawar Sari Roti 400g',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 6,
      name: 'Telur Ayam 1kg',
      barcode: '8996001440023',
      categoryId: 5,
      price: 25000,
      costPrice: 22000,
      stockQuantity: 12,
      minStockLevel: 3,
      description: 'Telur Ayam Kampung 1kg (±12 butir)',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 7,
      name: 'Minyak Goreng Bimoli 2L',
      barcode: '8996001440024',
      categoryId: 6,
      price: 28000,
      costPrice: 25000,
      stockQuantity: 18,
      minStockLevel: 4,
      description: 'Minyak Goreng Bimoli 2L',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 8,
      name: 'Gula Pasir Gulaku 1kg',
      barcode: '8996001440025',
      categoryId: 7,
      price: 15000,
      costPrice: 13000,
      stockQuantity: 22,
      minStockLevel: 5,
      description: 'Gula Pasir Gulaku 1kg',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 9,
      name: 'Kopi Kapal Api Special Mix',
      barcode: '8996001440026',
      categoryId: 8,
      price: 8500,
      costPrice: 7000,
      stockQuantity: 35,
      minStockLevel: 8,
      description: 'Kopi Kapal Api Special Mix 200g',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Product(
      id: 10,
      name: 'Sabun Mandi Lifebuoy',
      barcode: '8996001440027',
      categoryId: 9,
      price: 3200,
      costPrice: 2800,
      stockQuantity: 40,
      minStockLevel: 10,
      description: 'Sabun Mandi Lifebuoy Cool Fresh 75g',
      imageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static List<String> categories = [
    'Makanan Instan',
    'Minuman',
    'Beras & Serealia',
    'Roti & Kue',
    'Telur & Susu',
    'Minyak & Bumbu',
    'Gula & Penyedap',
    'Kopi & Teh',
    'Kebutuhan Rumah Tangga',
  ];

  static List<Product> getRecommendedProducts() {
    // Return random 3 products as recommendations
    final shuffled = List<Product>.from(products)..shuffle();
    return shuffled.take(3).toList();
  }

  static Product? findProductByBarcode(String barcode) {
    return products.firstWhere(
      (product) => product.barcode == barcode,
      orElse: () => products.first,
    );
  }

  static List<Product> searchProducts(String query) {
    if (query.isEmpty) return products;
    return products
        .where(
          (product) =>
              product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.barcode.contains(query),
        )
        .toList();
  }
}
