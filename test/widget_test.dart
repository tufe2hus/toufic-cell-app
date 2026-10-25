import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/models/product_model.dart';
import 'package:store_app/providers/cart_provider.dart';
import 'package:store_app/widgets/cart_panel.dart';

Product _buildProduct({
  required String id,
  required String name,
  double sellingPrice = 100,
  int quantity = 5,
}) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: name,
    normalizedName: name.toLowerCase(),
    serialNumber: '',
    barcode: '',
    categoryId: 'cat-1',
    categoryName: 'General',
    purchasePrice: sellingPrice / 2,
    sellingPrice: sellingPrice,
    quantity: quantity,
    minimumStock: 1,
    description: '',
    isSerialized: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    createdBy: 'tester',
  );
}

Widget _wrap(CartProvider cart) {
  return ChangeNotifierProvider<CartProvider>.value(
    value: cart,
    child: const MaterialApp(home: Scaffold(body: CartPanel())),
  );
}

void main() {
  testWidgets('shows an empty-cart message with no items added', (
    tester,
  ) async {
    final cart = CartProvider();
    await tester.pumpWidget(_wrap(cart));

    expect(find.text('Tap a product to add it to the sale.'), findsOneWidget);
  });

  testWidgets('renders a line item and running total after adding a product', (
    tester,
  ) async {
    final cart = CartProvider();
    cart.add(_buildProduct(id: 'p1', name: 'iPhone 15', sellingPrice: 100));
    await tester.pumpWidget(_wrap(cart));

    expect(find.text('iPhone 15'), findsOneWidget);
    expect(find.text('\$100.00'), findsWidgets);
  });

  testWidgets('increments quantity and updates the total when tapping +', (
    tester,
  ) async {
    final cart = CartProvider();
    cart.add(_buildProduct(id: 'p1', name: 'Charger', sellingPrice: 20));
    await tester.pumpWidget(_wrap(cart));

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    expect(cart.totalUnits, 2);
    expect(find.text('\$40.00'), findsWidgets);
  });
}
