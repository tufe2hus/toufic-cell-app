import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/product_model.dart';
import 'price_text.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onActionPressed,
    this.actionIcon,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final stockText = product.isOutOfStock
        ? 'Out of stock'
        : product.isLowStock
        ? 'Low stock (${product.quantity})'
        : 'Stock ${product.quantity}';
    final stockColor = product.isOutOfStock
        ? Theme.of(context).colorScheme.error
        : product.isLowStock
        ? Colors.orange.shade800
        : Theme.of(context).colorScheme.secondary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: product.hasImage
                    ? Image.memory(
                        base64Decode(product.imageBase64!),
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.devices_other_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stockText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: stockColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: PriceText(
                          product.sellingPrice,
                          currency: product.currency,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (onActionPressed != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: onActionPressed,
                          icon: Icon(
                            actionIcon ?? Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
