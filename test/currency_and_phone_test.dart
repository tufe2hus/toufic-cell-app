import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/currency.dart';
import 'package:store_app/utils/phone_normalization.dart';

void main() {
  group('Phone normalization', () {
    test('recognizes equivalent Lebanese numbers as the same customer', () {
      const expected = '70123456';
      expect(normalizeLebanesePhone('70123456'), expected);
      expect(normalizeLebanesePhone('70 123 456'), expected);
      expect(normalizeLebanesePhone('+961 70 123 456'), expected);
      expect(normalizeLebanesePhone('00961 70 123 456'), expected);
    });

    test('empty input normalizes to empty string', () {
      expect(normalizeLebanesePhone(''), '');
      expect(normalizeLebanesePhone('   '), '');
    });

    test('phone formatting does not add a country code automatically', () {
      expect(formatLebanesePhoneDigits('76889816'), '76 889 816');
      expect(formatLebanesePhoneDigits('+961 76 889 816'), '+961 76 889 816');
      expect(formatLebanesePhoneDigits(''), '');
    });
  });

  group('Currency minor units', () {
    test('USD converts to/from cents', () {
      expect(Currency.usd.toMinorUnits(12.5), 1250);
      expect(Currency.usd.fromMinorUnits(1250), 12.5);
    });

    test('LBP has no minor unit — whole Lira only', () {
      expect(Currency.lbp.toMinorUnits(1500000), 1500000);
      expect(Currency.lbp.fromMinorUnits(1500000), 1500000.0);
    });

    test('USD and LBP amounts are never combined by formatMoney', () {
      expect(formatMoney(20, Currency.usd), contains(r'$'));
      expect(formatMoney(1800000, Currency.lbp), contains('LBP'));
    });
  });
}
