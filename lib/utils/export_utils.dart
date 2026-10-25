import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bill_model.dart';
import '../models/business_record_models.dart';
import '../models/product_model.dart';
import '../models/shopping_list_item_model.dart';
import 'currency_format.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

String _timestamp() => DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

/// Deletes the excel package's default blank sheet once real content has
/// been written to a named sheet, so the exported file doesn't carry an
/// empty extra "Sheet1" tab.
void _dropDefaultSheet(xls.Excel workbook, String keepSheetName) {
  workbook.setDefaultSheet(keepSheetName);
  if (workbook.sheets.containsKey('Sheet1') && keepSheetName != 'Sheet1') {
    workbook.delete('Sheet1');
  }
}

/// Bold white-on-blue header style applied to every exported sheet's first
/// row, so column headers are unmistakable at a glance.
xls.CellStyle _headerStyle() => xls.CellStyle(
  bold: true,
  fontColorHex: xls.ExcelColor.white,
  backgroundColorHex: xls.ExcelColor.fromHexString('FF1D4ED8'),
  horizontalAlign: xls.HorizontalAlign.Center,
  verticalAlign: xls.VerticalAlign.Center,
);

/// Applies [style] across the first [columnCount] cells of [rowIndex] —
/// used to style a just-appended header row.
void _styleRow(
  xls.Sheet sheet,
  int rowIndex,
  int columnCount,
  xls.CellStyle style,
) {
  for (var column = 0; column < columnCount; column++) {
    sheet
        .cell(
          xls.CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: rowIndex,
          ),
        )
        .cellStyle = style;
  }
}

/// Sets a readable column width for each of [widths], in order.
void _setColumnWidths(xls.Sheet sheet, List<double> widths) {
  for (var column = 0; column < widths.length; column++) {
    sheet.setColumnWidth(column, widths[column]);
  }
}

/// Appends [headers] as a styled header row, then returns the row index the
/// next data row should use.
int _writeHeaderRow(xls.Sheet sheet, List<String> headers) {
  sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
  _styleRow(sheet, 0, headers.length, _headerStyle());
  return 1;
}

Future<void> exportTransactionsExcel({
  required List<TransactionRecord> transactions,
  required bool showProfit,
}) async {
  final workbook = xls.Excel.createExcel();
  const sheetName = 'Transactions';
  final sheet = workbook[sheetName];
  _dropDefaultSheet(workbook, sheetName);

  final headers = [
    'Invoice',
    'Date',
    'Customer',
    'Payment',
    'Items',
    'Total (\$)',
    if (showProfit) 'Profit (\$)',
  ];
  _writeHeaderRow(sheet, headers);
  for (final t in transactions) {
    sheet.appendRow([
      xls.TextCellValue(t.invoiceNumber),
      xls.TextCellValue(_dateFormat.format(t.createdAt)),
      xls.TextCellValue(t.customerName),
      xls.TextCellValue(t.paymentMethod),
      xls.IntCellValue(t.productCount),
      xls.DoubleCellValue(t.totalAmount),
      if (showProfit) xls.DoubleCellValue(t.profit),
    ]);
  }
  _setColumnWidths(sheet, [
    16,
    18,
    22,
    14,
    10,
    14,
    if (showProfit) 14,
  ]);

  workbook.save(fileName: 'transactions_${_timestamp()}.xlsx');
}

class ReportsExportData {
  const ReportsExportData({
    required this.dailySales,
    required this.weeklySales,
    required this.monthlySales,
    required this.monthlyProfitBeforeBills,
    required this.monthlyProfitAfterBills,
    required this.inventoryValue,
    required this.monthlyProfitSeries,
    required this.topSellingProducts,
    required this.categorySales,
    required this.usdToLbpRate,
    this.productProfit = const {},
    this.categoryProfit = const {},
  });

  final double dailySales;
  final double weeklySales;
  final double monthlySales;
  final double monthlyProfitBeforeBills;
  final double monthlyProfitAfterBills;
  final double inventoryValue;
  final Map<String, double> monthlyProfitSeries;
  final Map<String, double> topSellingProducts;
  final Map<String, double> categorySales;
  final double usdToLbpRate;
  final Map<String, double> productProfit;
  final Map<String, double> categoryProfit;
}

/// Everything the Reports screen's single "Export Excel" button produces:
/// one workbook covering the reports summary, every transaction, every
/// debtor and person owed, and every paid bill — each on its own sheet, so
/// there's one file to open instead of several separate exports.
Future<void> exportFullReportExcel({
  required ReportsExportData reportData,
  required List<TransactionRecord> transactions,
  required List<Debtor> debtors,
  required List<Debtor> creditors,
  required List<Bill> bills,
}) async {
  final workbook = xls.Excel.createExcel();
  const summarySheetName = 'Summary';
  final summary = workbook[summarySheetName];
  _dropDefaultSheet(workbook, summarySheetName);

  _writeHeaderRow(summary, ['Metric', 'USD', 'LBP']);
  void summaryRow(String label, double amount) {
    summary.appendRow([
      xls.TextCellValue(label),
      xls.DoubleCellValue(amount),
      xls.TextCellValue(formatLbp(amount, reportData.usdToLbpRate)),
    ]);
  }

  summaryRow('Daily sales', reportData.dailySales);
  summaryRow('Weekly sales', reportData.weeklySales);
  summaryRow('Monthly sales', reportData.monthlySales);
  summaryRow(
    'Monthly profit (before bills)',
    reportData.monthlyProfitBeforeBills,
  );
  summaryRow(
    'Monthly profit (after bills)',
    reportData.monthlyProfitAfterBills,
  );
  summaryRow('Inventory value', reportData.inventoryValue);
  _setColumnWidths(summary, [30, 16, 20]);

  void mapSheet(
    String name,
    Map<String, double> values, {
    String valueHeader = 'Value',
    Map<String, double>? profitByKey,
  }) {
    final sheet = workbook[name];
    final headers = ['Name', valueHeader, if (profitByKey != null) 'Profit'];
    _writeHeaderRow(sheet, headers);
    for (final entry in values.entries) {
      final profit = profitByKey?[entry.key];
      sheet.appendRow([
        xls.TextCellValue(entry.key),
        xls.DoubleCellValue(entry.value),
        if (profitByKey != null) xls.DoubleCellValue(profit ?? 0),
      ]);
    }
    _setColumnWidths(sheet, [28, 16, if (profitByKey != null) 16]);
  }

  mapSheet(
    'Monthly Profit',
    reportData.monthlyProfitSeries,
    valueHeader: 'Profit (\$)',
  );
  mapSheet(
    'Top Products',
    reportData.topSellingProducts,
    valueHeader: 'Sales (\$)',
    profitByKey: reportData.productProfit,
  );
  mapSheet(
    'Best Categories',
    reportData.categorySales,
    valueHeader: 'Sales (\$)',
    profitByKey: reportData.categoryProfit,
  );

  final txSheet = workbook['Transactions'];
  _writeHeaderRow(txSheet, [
    'Invoice',
    'Date',
    'Customer',
    'Payment',
    'Items',
    'Total (\$)',
    'Profit (\$)',
  ]);
  for (final t in transactions) {
    txSheet.appendRow([
      xls.TextCellValue(t.invoiceNumber),
      xls.TextCellValue(_dateFormat.format(t.createdAt)),
      xls.TextCellValue(t.customerName),
      xls.TextCellValue(t.paymentMethod),
      xls.IntCellValue(t.productCount),
      xls.DoubleCellValue(t.totalAmount),
      xls.DoubleCellValue(t.profit),
    ]);
  }
  _setColumnWidths(txSheet, [16, 18, 22, 14, 10, 14, 14]);

  void debtLedgerSheet(String name, List<Debtor> people) {
    final sheet = workbook[name];
    _writeHeaderRow(sheet, [
      'Name',
      'Phone',
      'USD total',
      'USD paid',
      'USD remaining',
      'LBP total',
      'LBP paid',
      'LBP remaining',
      'Due date',
      'Status',
      'Note',
    ]);
    for (final person in people) {
      sheet.appendRow([
        xls.TextCellValue(person.name),
        xls.TextCellValue(person.phoneNumber),
        xls.DoubleCellValue(person.usdTotalDebt),
        xls.DoubleCellValue(person.usdTotalPaid),
        xls.DoubleCellValue(person.usdRemainingAmount),
        xls.DoubleCellValue(person.lbpTotalDebtAmount),
        xls.DoubleCellValue(person.lbpTotalPaidAmount),
        xls.DoubleCellValue(person.lbpRemainingAmount),
        xls.TextCellValue(
          person.dueDate == null ? '' : _dateFormat.format(person.dueDate!),
        ),
        xls.TextCellValue(person.isSettled ? 'Settled' : 'Pending'),
        xls.TextCellValue(person.note),
      ]);
    }
    _setColumnWidths(sheet, [
      20,
      16,
      12,
      12,
      14,
      14,
      14,
      16,
      16,
      12,
      24,
    ]);
  }

  debtLedgerSheet('Debtors', debtors);
  debtLedgerSheet('People I Owe', creditors);

  final billsSheet = workbook['Bills'];
  _writeHeaderRow(billsSheet, [
    'Name',
    'Amount (\$)',
    'Note',
    'Paid at',
    'Paid by',
  ]);
  for (final bill in bills) {
    billsSheet.appendRow([
      xls.TextCellValue(bill.name),
      xls.DoubleCellValue(bill.amount),
      xls.TextCellValue(bill.note),
      xls.TextCellValue(_dateFormat.format(bill.paidAt)),
      xls.TextCellValue(bill.paidBy),
    ]);
  }
  _setColumnWidths(billsSheet, [24, 14, 24, 18, 18]);

  workbook.save(fileName: 'full_report_${_timestamp()}.xlsx');
}

Future<void> exportDebtorsExcel(List<Debtor> debtors) async {
  final workbook = xls.Excel.createExcel();
  const sheetName = 'Debtors';
  final sheet = workbook[sheetName];
  _dropDefaultSheet(workbook, sheetName);
  _writeHeaderRow(sheet, [
    'Name',
    'Phone',
    'USD remaining',
    'LBP remaining',
    'Due date',
    'Status',
  ]);

  for (final debtor in debtors) {
    sheet.appendRow([
      xls.TextCellValue(debtor.name),
      xls.TextCellValue(debtor.phoneNumber),
      xls.DoubleCellValue(debtor.usdRemainingAmount),
      xls.DoubleCellValue(debtor.lbpRemainingAmount),
      xls.TextCellValue(
        debtor.dueDate == null ? '' : DateFormat('dd/MM/yyyy').format(debtor.dueDate!),
      ),
      xls.TextCellValue(debtor.isSettled ? 'Settled' : 'Pending'),
    ]);
  }
  _setColumnWidths(sheet, [24, 18, 18, 18, 16, 14]);
  workbook.save(fileName: 'debtors_${_timestamp()}.xlsx');
}

/// Opens the OS print dialog with a printable page listing the goods still
/// to bring in (unbought items first, then already-bought ones crossed off),
/// so it can be printed on paper and taken along on the supplier run.
Future<void> printShoppingList(List<ShoppingListItem> items) async {
  final doc = pw.Document();
  final pending = items.where((item) => !item.isBought).toList();
  final bought = items.where((item) => item.isBought).toList();

  pw.Widget itemRow(ShoppingListItem item) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 14,
            height: 14,
            margin: const pw.EdgeInsets.only(top: 2, right: 8),
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.rectangle,
              border: pw.Border.all(width: 1),
              color: item.isBought ? PdfColors.grey400 : null,
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${item.name} ×${item.quantity}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    decoration: item.isBought
                        ? pw.TextDecoration.lineThrough
                        : null,
                    color: item.isBought ? PdfColors.grey600 : PdfColors.black,
                  ),
                ),
                if (item.note.isNotEmpty)
                  pw.Text(
                    item.note,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(
          'Goods to bring',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated ${_dateFormat.format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        if (pending.isEmpty && bought.isEmpty)
          pw.Text('Nothing on the list yet.')
        else ...[
          if (pending.isNotEmpty) ...pending.map(itemRow),
          if (bought.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Already bought',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            ...bought.map(itemRow),
          ],
        ],
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: 'shopping_list_${_timestamp()}.pdf',
  );
}
