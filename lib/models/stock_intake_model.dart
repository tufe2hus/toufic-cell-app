import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency.dart';

/// One "goods brought into the store" event — logged automatically whenever
/// a product is created or an existing product's quantity is increased (see
/// AppProvider.saveProduct). Never created for a quantity *decrease* (that's
/// a correction, not new stock arriving). This is the only record of when
/// stock actually arrived — a product's own `quantity` field is just the
/// current total, with no history of individual restocks.
class StockIntake {
  const StockIntake({
    required this.id,
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.quantityAdded,
    required this.purchasePrice,
    required this.currency,
    required this.isNewProduct,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String categoryName;
  /// How many units were added in this event (always positive).
  final int quantityAdded;
  /// Unit cost at the time of this intake (the product's purchase price
  /// when this event happened — not necessarily today's purchase price).
  final double purchasePrice;
  final Currency currency;
  /// True when this is a brand-new product's very first stock; false when
  /// it's a restock of a product that already existed.
  final bool isNewProduct;
  final String createdBy;
  final DateTime createdAt;

  double get totalCost => purchasePrice * quantityAdded;

  factory StockIntake.fromMap(Map<String, dynamic> data, String id) {
    return StockIntake(
      id: id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      quantityAdded: (data['quantityAdded'] as num?)?.toInt() ?? 0,
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      currency: Currency.fromStorage(data['currency'] as String?),
      isNewProduct: data['isNewProduct'] as bool? ?? false,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'categoryName': categoryName,
    'quantityAdded': quantityAdded,
    'purchasePrice': purchasePrice,
    'currency': currency.storageValue,
    'isNewProduct': isNewProduct,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
