import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens a camera dialog and returns the first scanned barcode value, or
/// `null` if the dialog was cancelled or no camera is available.
Future<String?> scanBarcode(BuildContext context) async {
  final scannerController = MobileScannerController();
  String? scannedValue;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Scan barcode'),
          content: SizedBox(
            width: 320,
            height: 360,
            child: MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                final value = capture.barcodes.firstOrNull?.rawValue;
                if (value != null && scannedValue == null) {
                  scannedValue = value;
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open camera scanner on this device.'),
        ),
      );
    }
  } finally {
    await scannerController.dispose();
  }

  return scannedValue;
}
