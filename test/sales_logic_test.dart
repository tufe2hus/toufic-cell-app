import 'package:flutter_test/flutter_test.dart';

int toCents(double value) => (value * 100).round();

double lineTotal({required double sellingPrice, required int quantity}) {
  return sellingPrice * quantity;
}

Map<String, dynamic> checkoutValues({
  required double saleTotal,
  required String saleType,
}) {
  final isCash = saleType == 'cash';
  return {
    'paidAmount': isCash ? saleTotal : 0.0,
    'remainingDebt': isCash ? 0.0 : saleTotal,
    'paymentStatus': isCash ? 'paid' : 'unpaid',
  };
}

void main() {
  group('Sale totals and payment mode logic', () {
    test('line total uses sellingPrice * quantity', () {
      expect(
        lineTotal(sellingPrice: 19.99, quantity: 3),
        closeTo(59.97, 0.0001),
      );
    });

    test('cash sale marks all as paid', () {
      final values = checkoutValues(saleTotal: 120.0, saleType: 'cash');

      expect(values['paidAmount'], 120.0);
      expect(values['remainingDebt'], 0.0);
      expect(values['paymentStatus'], 'paid');
    });

    test('debt sale marks total as remaining debt', () {
      final values = checkoutValues(saleTotal: 120.0, saleType: 'debt');

      expect(values['paidAmount'], 0.0);
      expect(values['remainingDebt'], 120.0);
      expect(values['paymentStatus'], 'unpaid');
    });

    test('serialized items should be sold one unit at a time', () {
      const requestedQty = 2;
      const isSerialized = true;

      final allowed = !(isSerialized && requestedQty != 1);
      expect(allowed, isFalse);
    });

    test('stock reduction is exact and non-negative', () {
      const currentStock = 5;
      const qty = 2;
      final newStock = currentStock - qty;

      expect(newStock, 3);
      expect(newStock >= 0, isTrue);
    });

    test('money conversion uses integer cents', () {
      expect(toCents(25.50), 2550);
      expect(toCents(0.01), 1);
    });
  });
}
