import 'package:flutter/material.dart';

class StoreNavigationItem {
  const StoreNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  /// If non-null, a small red badge with this text is shown on the icon.
  final String? badge;
}

class StoreNavigationRail extends StatelessWidget {
  const StoreNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<StoreNavigationItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.8,
      destinations: items
          .map(
            (item) => NavigationRailDestination(
              icon: _BadgedIcon(item: item, selected: false),
              selectedIcon: _BadgedIcon(item: item, selected: true),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }
}

class StoreBottomNavigation extends StatelessWidget {
  const StoreBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<StoreNavigationItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: _BadgedIcon(item: item, selected: false),
              selectedIcon: _BadgedIcon(item: item, selected: true),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}

/// Wraps an icon with a small numeric badge when [item.badge] is set.
class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.item, required this.selected});

  final StoreNavigationItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? item.selectedIcon : item.icon);
    if (item.badge == null) return icon;
    return Badge(label: Text(item.badge!), child: icon);
  }
}
