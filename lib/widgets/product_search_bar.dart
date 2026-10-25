import 'package:flutter/material.dart';

class ProductSearchBar extends StatelessWidget {
  const ProductSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search products, serial, barcode, category',
    this.autofocus = false,
    this.onScanTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;

  /// When provided, shows a camera icon that lets the user scan a barcode
  /// instead of typing it.
  final VoidCallback? onScanTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onScanTap != null)
              IconButton(
                tooltip: 'Scan barcode',
                onPressed: onScanTap,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            controller.text.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.tune_rounded),
                  )
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ],
        ),
      ),
    );
  }
}
