import 'product_model.dart';

class CartItem {
  CartItem({required this.product, required this.quantity});

  /// Snapshot of the product at the time it was added to the cart.
  /// Checkout re-validates stock against Firestore, so staleness here only
  /// affects the client-side quantity cap shown while shopping.
  final Product product;
  final int quantity;

  double get lineTotal => product.sellingPrice * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);
}

enum CartAddResult {
  added,
  incremented,
  cappedByStock,
  cappedSerialized,
  unavailable,
  differentCurrency,
}
