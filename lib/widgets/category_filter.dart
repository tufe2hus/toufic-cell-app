import 'package:flutter/material.dart';

class CategoryFilter extends StatelessWidget {
  const CategoryFilter({
    super.key,
    required this.categories,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<CategoryFilterItem> categories;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map(
              (category) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(category.label),
                  selected: selectedValue == category.value,
                  onSelected: (_) => onSelected(category.value),
                  avatar: category.icon == null
                      ? null
                      : Icon(category.icon, size: 18),
                  labelStyle: TextStyle(
                    color: selectedValue == category.value
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class CategoryFilterItem {
  const CategoryFilterItem({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;
}

List<CategoryFilterItem> buildCategoryFilterItems(
  List<MapEntry<String, String>> categories,
) {
  return [
    const CategoryFilterItem(
      label: 'All',
      value: 'all',
      icon: Icons.grid_view_rounded,
    ),
    ...categories.map(
      (entry) => CategoryFilterItem(label: entry.value, value: entry.key),
    ),
  ];
}
