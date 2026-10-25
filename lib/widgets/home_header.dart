import 'package:flutter/material.dart';

import 'product_search_bar.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.userLabel,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.metrics,
    this.onScanTap,
  });

  final String userLabel;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final List<HomeHeaderMetric> metrics;
  final VoidCallback? onScanTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF0F5AF2), Color(0xFF0E9F9A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toufic Cell',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Welcome, $userLabel',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A modern mobile-store workspace for inventory, prices, debtor follow-up, and daily sales decisions.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.smartphone_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: ProductSearchBar(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        hintText: 'Search products from the home page',
                        onScanTap: onScanTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onSearchSubmitted,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Products'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                // Fixed 170px tiles only fit 4-per-row on wide screens. On
                // narrow phones that leaves just one tile per row, which
                // stretches this whole header far taller than it should
                // be — so below that width, size tiles to always fit two
                // per row instead.
                const spacing = 12.0;
                const fixedTileWidth = 170.0;
                final fitsFourAcross =
                    constraints.maxWidth >= (fixedTileWidth * 4) + (spacing * 3);
                final tileWidth = fitsFourAcross
                    ? fixedTileWidth
                    : (constraints.maxWidth - spacing) / 2;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: metrics
                      .map(
                        (metric) => ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.14),
                            child: InkWell(
                              onTap: metric.onTap,
                              child: Container(
                                width: tileWidth,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      metric.icon,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      metric.value,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    if (metric.secondaryValue != null)
                                      Text(
                                        metric.secondaryValue!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                            ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      metric.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeHeaderMetric {
  const HomeHeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.secondaryValue,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  /// Optional smaller line shown under [value], e.g. the LBP equivalent of
  /// a dollar amount.
  final String? secondaryValue;
}
