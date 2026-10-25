import 'package:url_launcher/url_launcher.dart';

import '../models/product_model.dart';

const _debtorReportWhatsAppNumber = '96176889816';

String buildDebtorReportMessage(List<Debtor> debtors) {
  final outstanding = debtors.where((debtor) => !debtor.isSettled).toList();
  final lines = outstanding.map((debtor) {
    final balances = <String>[
      if (debtor.usdRemainingAmount > 0)
        'USD ${debtor.usdRemainingAmount.toStringAsFixed(2)}',
      if (debtor.lbpRemainingAmount > 0)
        'LBP ${debtor.lbpRemainingAmount.toStringAsFixed(0)}',
    ].join(' / ');
    final phone = debtor.phoneNumber.isEmpty ? '' : ' · ${debtor.phoneNumber}';
    return '- ${debtor.name}$phone: $balances';
  });
  final message = [
    'Debtors report (${DateTime.now().toLocal().toString().split(' ').first})',
    if (lines.isEmpty) 'No outstanding debtors.' else ...lines,
  ].join('\n');
  return message;
}

Future<void> openDebtorReportInWhatsApp(String message) async {
  final uri = Uri.https('api.whatsapp.com', '/send', {
    'phone': _debtorReportWhatsAppNumber,
    'text': message,
  });

  if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
    throw StateError('Could not open WhatsApp.');
  }
}
