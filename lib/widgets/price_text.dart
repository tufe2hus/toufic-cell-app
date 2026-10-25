import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../providers/app_provider.dart';
import '../utils/currency_format.dart';

/// Shows a money amount. For USD (the default, matching every pre-existing
/// call site) it also shows the Lebanese Lira *equivalent* underneath, using
/// the admin-configured exchange rate (Admin Tools → Currency) — purely a
/// display conversion, not a stored amount. For a genuinely LBP-denominated
/// amount (a product/sale/debt actually priced in LBP), only the real LBP
/// figure is shown — USD and LBP are never auto-combined into one number.
class PriceText extends StatelessWidget {
  const PriceText(
    this.amount, {
    super.key,
    this.style,
    this.lbpStyle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.currency = Currency.usd,
  });

  final double amount;
  final TextStyle? style;
  final TextStyle? lbpStyle;
  final CrossAxisAlignment crossAxisAlignment;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    if (currency == Currency.lbp) {
      return Text(
        formatMoney(amount, Currency.lbp),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final rate = context.watch<AppProvider>().usdToLbpRate;
    final usdFormatter = NumberFormat.currency(symbol: r'$');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          usdFormatter.format(amount),
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          formatLbp(amount, rate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              lbpStyle ??
              Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
