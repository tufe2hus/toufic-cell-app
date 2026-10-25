import 'package:intl/intl.dart';

final _lbpFormatter = NumberFormat.decimalPattern('en_US');

/// Formats a USD amount as its Lebanese Lira equivalent using the given
/// USD→LBP rate, e.g. "LBP 1,080,000". LBP has no minor unit in everyday use,
/// so amounts are rounded to whole Lira.
String formatLbp(double usdAmount, double rate) {
  return 'LBP ${_lbpFormatter.format((usdAmount * rate).round())}';
}
