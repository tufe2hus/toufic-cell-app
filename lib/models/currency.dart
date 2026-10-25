import 'package:intl/intl.dart';

/// The two currencies the store trades in. Every stored money amount is
/// tagged with exactly one of these — amounts are never auto-combined
/// across currencies (see requirement: "Do NOT automatically combine USD
/// and LBP").
enum Currency {
  usd,
  lbp;

  String get storageValue => name;

  String get symbol => this == Currency.usd ? r'$' : 'L.L.';

  static Currency fromStorage(String? value) {
    switch (value) {
      case 'lbp':
        return Currency.lbp;
      case 'usd':
      default:
        return Currency.usd;
    }
  }

  /// Converts a display amount to integer "minor units" for exact ledger
  /// math: cents for USD (x100), whole Lira for LBP (LBP has no minor
  /// unit in everyday use, so its minor unit is itself).
  int toMinorUnits(double amount) =>
      this == Currency.usd ? (amount * 100).round() : amount.round();

  double fromMinorUnits(int minorUnits) =>
      this == Currency.usd ? minorUnits / 100.0 : minorUnits.toDouble();
}

final _usdFormatter = NumberFormat.currency(symbol: r'$');
final _lbpFormatter = NumberFormat.decimalPattern('en_US');

/// LBP has no minor unit in everyday use, so amounts round to whole Lira.
/// USD keeps two decimal places via [NumberFormat.currency].
String formatMoney(double amount, Currency currency) {
  return currency == Currency.usd
      ? _usdFormatter.format(amount)
      : '${_lbpFormatter.format(amount.round())} LBP';
}

/// Smallest "quick adjustment" step for manual invoice adjustments and
/// similar rounding, appropriate to each currency's everyday denomination.
class CurrencySteps {
  static const double usdSmall = 1;
  static const double usdLarge = 5;
  static const double lbpSmall = 5000;
  static const double lbpLarge = 25000;

  static double small(Currency currency) =>
      currency == Currency.usd ? usdSmall : lbpSmall;
  static double large(Currency currency) =>
      currency == Currency.usd ? usdLarge : lbpLarge;
}
