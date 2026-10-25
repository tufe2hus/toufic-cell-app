/// Sales/profit figures for one calendar day, plus which products were sold
/// that day — powers the Reports screen's daily-profit-by-month bar chart
/// (see [AppProvider.dailyProfitForMonth]).
class DailyProfitEntry {
  const DailyProfitEntry({
    required this.day,
    required this.salesAmount,
    required this.profitBeforeBills,
    required this.profitAfterBills,
    required this.productSales,
  });

  final DateTime day;
  final double salesAmount;
  final double profitBeforeBills;
  final double profitAfterBills;
  /// Product name -> total sale amount for that day, sorted highest first.
  final Map<String, double> productSales;
}
