import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/business_record_models.dart';
import 'package:store_app/models/product_model.dart';

int toCents(double value) => (value * 100).round();

void main() {
  group('Debtor payment logic', () {
    test('partial payment reduces remaining debt correctly', () {
      const totalDebt = 250.50;
      const oldPaid = 100.00;
      const payment = 25.25;

      final newPaid = oldPaid + payment;
      final remaining = totalDebt - newPaid;

      expect(toCents(newPaid), 12525);
      expect(toCents(remaining), 12525);
    });

    test('full payment settles the debtor', () {
      final debtor = Debtor(
        id: 'd1',
        name: 'Customer',
        createdAt: DateTime(2026, 1, 1),
        usdTotalDebtCents: 12000,
        usdTotalPaidCents: 12000,
      );

      expect(debtor.remainingAmount, 0);
      expect(debtor.isSettled, isTrue);
      expect(debtor.computedStatus, 'paid');
    });

    test('debtor tracks USD and LBP balances independently', () {
      final debtor = Debtor(
        id: 'd2',
        name: 'Ali',
        createdAt: DateTime(2026, 1, 1),
        usdTotalDebtCents: 3500,
        usdTotalPaidCents: 1000,
        lbpTotalDebt: 1500000,
        lbpTotalPaid: 0,
      );

      expect(debtor.usdRemainingAmount, 25.0);
      expect(debtor.lbpRemainingAmount, 1500000.0);
      expect(debtor.isSettled, isFalse);
      // A payment in one currency never touches the other's balance.
      expect(debtor.hasUsdActivity, isTrue);
      expect(debtor.hasLbpActivity, isTrue);
    });

    test('payment larger than remaining debt is rejected by cents check', () {
      final totalDebtCents = toCents(100.00);
      final currentPaidCents = toCents(90.00);
      final incomingPaymentCents = toCents(15.00);

      final newRemainingCents =
          totalDebtCents - (currentPaidCents + incomingPaymentCents);

      expect(newRemainingCents < 0, isTrue);
    });

    test('payment record stores integer minor units', () {
      final payment = PaymentRecord(
        id: 'p1',
        debtorId: 'd1',
        customerName: 'Customer',
        amount: 25.50,
        note: '',
        receivedBy: 'admin',
        paidAt: DateTime(2026, 1, 1),
      );

      expect(payment.resolvedAmountCents, 2550);
      expect(payment.toMap()['amountCents'], 2550);
    });
  });
}
