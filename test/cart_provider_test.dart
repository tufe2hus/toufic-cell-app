import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/cart_item.dart';
import 'package:store_app/models/currency.dart';
import 'package:store_app/models/product_model.dart';
import 'package:store_app/providers/cart_provider.dart';

Product _product({
  required String id,
  double sellingPrice = 10,
  int quantity = 5,
  Currency currency = Currency.usd,
}) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: 'Product $id',
    normalizedName: 'product $id',
    serialNumber: '',
    barcode: '',
    categoryId: 'cat',
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
    currency: currency,
  );
}

void main() {
  group('CartProvider manual adjustment (requirement 11)', () {
    test('adjustment changes final total but never the subtotal', () {
      final cart = CartProvider();
      cart.add(_product(id: 'p1', sellingPrice: 10));

      expect(cart.subtotal, 10);
      cart.adjustManual(1);
      expect(cart.manualAdjustment, 1);
      expect(cart.finalTotal, 11);
      expect(cart.subtotal, 10);

      cart.adjustManual(1);
      expect(cart.finalTotal, 12);

      cart.adjustManual(-5);
      expect(cart.finalTotal, 7);
    });

    test('final total never goes negative', () {
      final cart = CartProvider();
      cart.add(_product(id: 'p1', sellingPrice: 10));

      cart.adjustManual(-100);
      expect(cart.finalTotal, 0);
    });

    test('clearing the cart resets the adjustment', () {
      final cart = CartProvider();
      cart.add(_product(id: 'p1', sellingPrice: 10));
      cart.adjustManual(5);
      cart.clear();

      expect(cart.manualAdjustment, 0);
    });
  });

  group('CartProvider quantity controls (requirement 12)', () {
    test('cannot exceed available stock', () {
      final cart = CartProvider();
      final product = _product(id: 'p1', quantity: 3);
      cart.add(product);
      cart.increment('p1');
      cart.increment('p1');
      final result = cart.increment('p1');

      expect(cart.quantityInCart('p1'), 3);
      expect(result, CartAddResult.cappedByStock);
    });

    test('decrementing to zero removes the item (trash behavior)', () {
      final cart = CartProvider();
      cart.add(_product(id: 'p1'));
      cart.decrement('p1');

      expect(cart.isEmpty, isTrue);
    });
  });

  group('CartProvider currency isolation (requirement 3)', () {
    test('refuses to mix USD and LBP items in the same cart', () {
      final cart = CartProvider();
      cart.add(_product(id: 'usd-item', currency: Currency.usd));
      final result = cart.add(_product(id: 'lbp-item', currency: Currency.lbp));

      expect(result, CartAddResult.differentCurrency);
      expect(cart.lineItemCount, 1);
    });
  });
}
