import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/admin_note_model.dart';
import '../../models/cart_item.dart';
import '../../models/currency.dart';
import '../../models/product_model.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../screens/admin/product_management_screen.dart';
import '../../screens/bills/bills_management_screen.dart';
import '../../screens/creditors/creditors_management_screen.dart';
import '../../screens/debtors/debtors_management_screen.dart';
import '../../screens/inventory/shopping_list_screen.dart';
import '../../screens/inventory/stock_intake_screen.dart';
import '../../screens/maintenance/maintenance_management_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/settings/currency_settings_screen.dart';
import '../../screens/settings/user_management_screen.dart';
import '../../screens/storefront/storefront_management_screen.dart';
import '../../screens/transactions/transactions_screen.dart';
import '../../services/connectivity_service.dart';
import '../../theme/toufic_cell_theme.dart';
import '../../utils/barcode_scanner.dart';
import '../../utils/contacts_picker.dart';
import '../../utils/currency_format.dart';
import '../../utils/phone_normalization.dart';
import '../../widgets/admin_notes_card.dart';
import '../../widgets/cart_panel.dart';
import '../../widgets/category_filter.dart';
import '../../widgets/home_header.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_search_bar.dart';
import '../../widgets/store_navigation.dart';

class StoreDashboardScreen extends StatefulWidget {
  const StoreDashboardScreen({super.key});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  String _selectedCategoryId = 'all';

  // ── In-app notification tracking ─────────────────────────────────────────
  final Set<String> _seenNoteIds = {};
  bool _notesInitialized = false;

  // ── Connectivity ──────────────────────────────────────────────────────────
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    ConnectivityService.onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.isConnected();
    if (mounted) setState(() => _isOnline = online);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1080;
    final showRightPanel = width >= 1420;

    // ── Detect new admin notes and show in-app notification ─────────────────
    _detectNewNotes(context, provider.adminNotes);

    final items = _buildNavigationItems(provider);
    final pages = [
      _HomeTab(
        searchController: _searchController,
        onSearchChanged: _handleSearchChanged,
        onSearchSubmitted: () {
          setState(() => _selectedIndex = 1);
        },
        onOpenDebtors: _openDebtors,
        onOpenCreditors: _openCreditors,
      ),
      _ProductsTab(
        searchController: _searchController,
        selectedCategoryId: _selectedCategoryId,
        onSearchChanged: _handleSearchChanged,
        onCategorySelected: (value) =>
            setState(() => _selectedCategoryId = value),
      ),
      _SalesLauncherTab(
        onOpenDebtors: _openDebtors,
        onOpenCreditors: _openCreditors,
      ),
      _ToolsTab(
        isAdmin: provider.isAdmin,
        onOpenDebtors: _openDebtors,
        onOpenCreditors: _openCreditors,
      ),
    ];

    return Scaffold(
      appBar: isWide ? null : _buildMobileAppBar(context, provider),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Connectivity banner ──────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _isOnline
                  ? const SizedBox.shrink()
                  : Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No internet connection. Some features may be unavailable.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            // ── Main content row ─────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  if (isWide) _buildRailShell(context, provider, items),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 20 : 16,
                        16,
                        16,
                        16,
                      ),
                      child: pages[_selectedIndex],
                    ),
                  ),
                  if (showRightPanel && _selectedIndex != 1)
                    SizedBox(
                      width: 320,
                      child: _StorePulsePanel(notes: provider.adminNotes),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : StoreBottomNavigation(
              selectedIndex: _selectedIndex,
              items: items,
              onSelected: _onNavSelected,
            ),
    );
  }

  AppBar _buildMobileAppBar(BuildContext context, AppProvider provider) {
    return AppBar(
      title: const Text('Toufic Cell'),
      actions: [
        IconButton(
          onPressed: provider.toggleThemeMode,
          icon: Icon(
            provider.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
        IconButton(
          onPressed: () async {
            await provider.signOut();
          },
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }

  Widget _buildRailShell(
    BuildContext context,
    AppProvider provider,
    List<StoreNavigationItem> items,
  ) {
    return Container(
      width: 112,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TouficCellTheme.sideRail,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Toufic',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StoreNavigationRail(
              selectedIndex: _selectedIndex,
              items: items,
              onSelected: (index) => setState(() => _selectedIndex = index),
            ),
          ),
          IconButton(
            onPressed: provider.toggleThemeMode,
            icon: Icon(
              provider.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            onPressed: () async {
              await provider.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<StoreNavigationItem> _buildNavigationItems(AppProvider provider) {
    final unread = provider.unreadNotesCount;
    return [
      StoreNavigationItem(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        badge: unread > 0 ? unread.toString() : null,
      ),
      const StoreNavigationItem(
        label: 'Products',
        icon: Icons.widgets_outlined,
        selectedIcon: Icons.widgets_rounded,
      ),
      const StoreNavigationItem(
        label: 'Sales',
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale_rounded,
      ),
      StoreNavigationItem(
        label: provider.isAdmin ? 'Admin' : 'More',
        icon: provider.isAdmin
            ? Icons.admin_panel_settings_outlined
            : Icons.menu_rounded,
        selectedIcon: provider.isAdmin
            ? Icons.admin_panel_settings_rounded
            : Icons.menu_open_rounded,
      ),
    ];
  }

  void _onNavSelected(int index) {
    setState(() => _selectedIndex = index);
    // When user navigates to Home tab, mark notes as read
    if (index == 0) {
      context.read<AppProvider>().markNotesRead();
    }
  }

  /// Detect genuinely new notes (after initial load) and show a SnackBar.
  void _detectNewNotes(BuildContext context, List<AdminNote> notes) {
    if (!_notesInitialized) {
      if (notes.isNotEmpty) {
        _notesInitialized = true;
        _seenNoteIds.addAll(notes.map((n) => n.id));
      }
      return;
    }

    final newIds = notes
        .map((n) => n.id)
        .where((id) => !_seenNoteIds.contains(id))
        .toList();

    if (newIds.isEmpty) return;

    _seenNoteIds.addAll(newIds);

    // Show notification after the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final newNote = notes.firstWhere(
        (n) => newIds.contains(n.id),
        orElse: () => notes.first,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '📢 New admin note: ${newNote.title}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  void _handleSearchChanged(String value) {
    if (mounted) {
      setState(() {});
    }
  }

  /// Opens the Debtors screen and, if the user pressed "Add charge" on a
  /// debtor there (which pops `true` after arming the cart via
  /// [CartProvider.startChargeFor]), switches to the Products tab so they
  /// can pick what that debtor is taking.
  Future<void> _openDebtors() async {
    final switchToProducts = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DebtorsManagementScreen()),
    );
    if (switchToProducts == true && mounted) {
      setState(() => _selectedIndex = 1);
    }
  }

  Future<void> _openCreditors() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreditorsManagementScreen()),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onOpenDebtors,
    required this.onOpenCreditors,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onOpenDebtors;
  final VoidCallback onOpenCreditors;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = NumberFormat.currency(symbol: r'$');
    final userLabel = _displayUserLabel(provider);

    return ListView(
      children: [
        HomeHeader(
          userLabel: userLabel,
          searchController: searchController,
          onSearchChanged: onSearchChanged,
          onSearchSubmitted: onSearchSubmitted,
          onScanTap: () => _scanIntoSearch(
            context,
            searchController,
            onSearchChanged,
            onSearchSubmitted,
          ),
          metrics: [
            HomeHeaderMetric(
              label: 'Products',
              value: provider.totalProducts.toString(),
              icon: Icons.inventory_2_rounded,
            ),
            HomeHeaderMetric(
              label: 'Low/out of stock',
              value: (provider.lowStockProducts + provider.outOfStockProducts)
                  .toString(),
              icon: Icons.warning_amber_rounded,
              onTap: () => _showLowStockDialog(context, provider),
            ),
            HomeHeaderMetric(
              label: 'Debtors',
              value: provider.pendingDebtors.toString(),
              icon: Icons.people_alt_rounded,
            ),
            if (provider.isAdmin)
              HomeHeaderMetric(
                label: 'Today sales',
                value: currency.format(provider.todaySalesAmount),
                secondaryValue: formatLbp(
                  provider.todaySalesAmount,
                  provider.usdToLbpRate,
                ),
                icon: Icons.payments_rounded,
              ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final useSideBySide = constraints.maxWidth >= 1040;
            final notes = AdminNotesCard(
              notes: provider.adminNotes,
              canManage: provider.isAdmin,
              unreadCount: provider.unreadNotesCount,
              onCreate: (title, message, isImportant) async {
                await provider.createAdminNote(
                  title: title,
                  message: message,
                  isImportant: isImportant,
                );
              },
              onUpdate: (note, title, message, isImportant) async {
                await provider.updateAdminNote(
                  note,
                  title: title,
                  message: message,
                  isImportant: isImportant,
                );
              },
              onDelete: provider.deleteAdminNote,
            );
            final quickActions = _QuickActionsPanel(
              isAdmin: provider.isAdmin,
              onOpenDebtors: onOpenDebtors,
              onOpenCreditors: onOpenCreditors,
            );

            if (!useSideBySide) {
              return Column(
                children: [notes, const SizedBox(height: 18), quickActions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: notes),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: quickActions),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({
    required this.searchController,
    required this.selectedCategoryId,
    required this.onSearchChanged,
    required this.onCategorySelected,
  });

  final TextEditingController searchController;
  final String selectedCategoryId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;

  void _handleAddToCart(BuildContext context, Product product) {
    final result = context.read<CartProvider>().add(product);
    String? message;
    switch (result) {
      case CartAddResult.added:
      case CartAddResult.incremented:
        message = null;
      case CartAddResult.cappedByStock:
        message = 'Only ${product.quantity} in stock for ${product.name}.';
      case CartAddResult.cappedSerialized:
        message =
            '${product.name} is already in the sale (sold one at a time).';
      case CartAddResult.unavailable:
        message = '${product.name} is out of stock.';
      case CartAddResult.differentCurrency:
        message =
            'Cart has items priced in a different currency. Clear the '
            'current sale before adding ${product.name}.';
    }
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showQuickSaleDialog(
    BuildContext context,
    AppProvider provider,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _QuickSaleDialog(provider: provider),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Widget _buildBrowser(
    BuildContext context,
    AppProvider provider,
    List<Product> filteredProducts,
    List<MapEntry<String, String>> categories,
  ) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Products',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a product to add it to the current sale, just like a real POS.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );

    final adminButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _showQuickSaleDialog(context, provider),
          icon: const Icon(Icons.flash_on_outlined),
          label: const Text('Quick sale'),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProductManagementScreen(),
              ),
            );
          },
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Manage products'),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MaintenanceManagementScreen(),
              ),
            );
          },
          icon: const Icon(Icons.build_circle_outlined),
          label: const Text('Maintenance'),
        ),
      ],
    );

    return ListView(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (!provider.isAdmin) {
              return titleColumn;
            }
            if (constraints.maxWidth >= 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleColumn),
                  const SizedBox(width: 16),
                  Flexible(child: adminButtons),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleColumn, const SizedBox(height: 14), adminButtons],
            );
          },
        ),
        const SizedBox(height: 18),
        ProductSearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
          onScanTap: () =>
              _scanIntoSearch(context, searchController, onSearchChanged),
        ),
        const SizedBox(height: 14),
        CategoryFilter(
          categories: buildCategoryFilterItems(categories),
          selectedValue: selectedCategoryId,
          onSelected: onCategorySelected,
        ),
        const SizedBox(height: 18),
        if (filteredProducts.isEmpty)
          const _EmptyStateCard(
            message: 'No products match the current search or category filter.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1260
                  ? 5
                  : constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 580
                  ? 3
                  : constraints.maxWidth >= 320
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return ProductCard(
                    product: product,
                    onTap: () => _handleAddToCart(context, product),
                    onActionPressed: provider.isAdmin
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProductManagementScreen(),
                              ),
                            );
                          }
                        : null,
                    actionIcon: provider.isAdmin
                        ? Icons.edit_outlined
                        : Icons.arrow_forward_rounded,
                  );
                },
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cart = context.watch<CartProvider>();
    final query = searchController.text.trim().toLowerCase();
    final categories = provider.categories
        .where((category) => category.isActive)
        .map((category) => MapEntry(category.id, category.name))
        .toList();
    final filteredProducts = provider.products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.serialNumber.toLowerCase().contains(query) ||
          product.categoryName.toLowerCase().contains(query);
      final matchesCategory =
          selectedCategoryId == 'all' ||
          product.categoryId == selectedCategoryId;
      return matchesQuery && matchesCategory;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final browser = _buildBrowser(
          context,
          provider,
          filteredProducts,
          categories,
        );

        final showCart = !cart.isEmpty || cart.chargeTarget != null;

        if (constraints.maxWidth >= 900 && showCart) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: browser),
              const SizedBox(width: 16),
              SizedBox(
                width: 360,
                height: constraints.maxHeight,
                child: const CartPanel(),
              ),
            ],
          );
        }

        return Stack(
          children: [
            browser,
            if (showCart)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _CartSummaryBar(cart: cart),
              ),
          ],
        );
      },
    );
  }
}

/// Logs a one-off sale of an item that isn't tracked in inventory — e.g. a
/// single unit the store only has once and doesn't want to create a
/// permanent product record for. Just name, cost, and selling price; the
/// profit is computed and counted toward reports exactly like a normal sale.
class _QuickSaleDialog extends StatefulWidget {
  const _QuickSaleDialog({required this.provider});

  final AppProvider provider;

  @override
  State<_QuickSaleDialog> createState() => _QuickSaleDialogState();
}

class _QuickSaleDialogState extends State<_QuickSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _sellingController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  Currency _currency = Currency.usd;
  bool _asDebt = false;
  bool _isSaving = false;

  double get _cost => double.tryParse(_costController.text.trim()) ?? 0;
  double get _selling => double.tryParse(_sellingController.text.trim()) ?? 0;
  double get _profit => _selling - _cost;

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomerContact() async {
    final contact = await pickPhoneContact();
    if (contact == null || !mounted) return;
    if (contact.name.isNotEmpty) _customerNameController.text = contact.name;
    if (contact.phone.isNotEmpty) {
      _customerPhoneController.text = formatLebanesePhoneDigits(contact.phone);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.provider.createQuickSale(
        productName: _nameController.text.trim(),
        costPrice: _cost,
        sellingPrice: _selling,
        currency: _currency,
        asDebt: _asDebt,
        customerPhone: _customerPhoneController.text.trim(),
        customerName: _customerNameController.text.trim().isEmpty
            ? 'Walk-in Customer'
            : _customerNameController.text.trim(),
      );
      navigator.pop('Quick sale logged successfully.');
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to log sale: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick sale'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Product name is required.'
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cost price',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid cost.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Selling price',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid price.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<Currency>(
                  segments: const [
                    ButtonSegment(value: Currency.usd, label: Text('USD (\$)')),
                    ButtonSegment(
                      value: Currency.lbp,
                      label: Text('LBP (L.L.)'),
                    ),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (selection) =>
                      setState(() => _currency = selection.first),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customerNameController,
                  decoration: const InputDecoration(labelText: 'Customer name'),
                  validator: (value) =>
                      _asDebt && (value == null || value.trim().isEmpty)
                      ? 'Customer name is required for a debt sale.'
                      : null,
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Paid'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Debt'),
                      icon: Icon(Icons.receipt_long_outlined),
                    ),
                  ],
                  selected: {_asDebt},
                  onSelectionChanged: (selection) =>
                      setState(() => _asDebt = selection.first),
                ),
                if (_asDebt) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customerPhoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [LebanesePhoneInputFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Phone number (optional)',
                          ),
                        ),
                      ),
                      if (supportsContactPicker) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _pickCustomerContact,
                          icon: const Icon(Icons.contacts_outlined),
                          label: const Text('Contacts'),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Profit: ${formatMoney(_profit, _currency)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _profit >= 0
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                if (_currency == Currency.usd)
                  Text(
                    '≈ ${formatLbp(_profit, widget.provider.usdToLbpRate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$');
    final chargeTarget = cart.chargeTarget;
    final label = cart.isEmpty && chargeTarget != null
        ? 'Charging to ${chargeTarget.name} · tap a product to add it'
        : '${cart.totalUnits} item${cart.totalUnits == 1 ? '' : 's'} · ${currency.format(cart.totalAmount)}';
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: const CartPanel(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_upward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesLauncherTab extends StatelessWidget {
  const _SalesLauncherTab({
    required this.onOpenDebtors,
    required this.onOpenCreditors,
  });

  final VoidCallback onOpenDebtors;
  final VoidCallback onOpenCreditors;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = NumberFormat.currency(symbol: r'$');

    return ListView(
      children: [
        Text(
          'Sales Workspace',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Add items from the Products tab to build a sale, then complete checkout from the cart panel.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns = constraints.maxWidth >= 900;
            final launchCards = <_LaunchCard>[
              if (provider.isAdmin)
                _LaunchCard(
                  title: 'People I Owe',
                  description:
                      'Track people or suppliers you owe money to, and record what you pay them.',
                  icon: Icons.handshake_outlined,
                  onTap: onOpenCreditors,
                ),
              _LaunchCard(
                title: 'Debtors',
                description:
                    'Review accounts, record payments, and keep outstanding balances synchronized.',
                icon: Icons.people_alt_rounded,
                onTap: onOpenDebtors,
              ),
            ];

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: launchCards
                  .map(
                    (card) => SizedBox(
                      width: useTwoColumns
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth,
                      child: card,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shift Summary',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (provider.isAdmin)
                      _MiniStatCard(
                        label: 'Today sales',
                        value: currency.format(provider.todaySalesAmount),
                        secondaryValue: formatLbp(
                          provider.todaySalesAmount,
                          provider.usdToLbpRate,
                        ),
                      ),
                    _MiniStatCard(
                      label: 'Transactions',
                      value: provider.transactions.length.toString(),
                    ),
                    _MiniStatCard(
                      label: 'Outstanding debt',
                      value: currency.format(provider.outstandingDebtAmount),
                      secondaryValue: formatLbp(
                        provider.outstandingDebtAmount,
                        provider.usdToLbpRate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolsTab extends StatelessWidget {
  const _ToolsTab({
    required this.isAdmin,
    required this.onOpenDebtors,
    required this.onOpenCreditors,
  });

  final bool isAdmin;
  final VoidCallback onOpenDebtors;
  final VoidCallback onOpenCreditors;

  @override
  Widget build(BuildContext context) {
    final tiles = isAdmin
        ? <_LaunchCard>[
            _LaunchCard(
              title: 'Manage Products',
              description: 'Add, edit, and maintain product details and stock.',
              icon: Icons.inventory_2_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProductManagementScreen(),
                  ),
                );
              },
            ),
            _LaunchCard(
              title: 'Goods Brought In',
              description:
                  'See every new product and restock, logged automatically by month.',
              icon: Icons.move_to_inbox_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StockIntakeScreen()),
                );
              },
            ),
            _LaunchCard(
              title: 'Goods To Bring',
              description:
                  'Write down what to buy or restock on your next supplier run, and print the list.',
              icon: Icons.checklist_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                );
              },
            ),
            _LaunchCard(
              title: 'Transactions',
              description: 'Review synchronized transaction history.',
              icon: Icons.receipt_long_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                );
              },
            ),
            _LaunchCard(
              title: 'Reports',
              description: 'Open the existing reports and analytics tools.',
              icon: Icons.analytics_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
            _LaunchCard(
              title: 'Pay Bills',
              description:
                  'Log paid bills and expenses — subtracted from profit reports.',
              icon: Icons.request_quote_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BillsManagementScreen(),
                  ),
                );
              },
            ),
            _LaunchCard(
              title: 'People I Owe',
              description:
                  'Track people or suppliers you owe money to, and record what you pay them.',
              icon: Icons.handshake_outlined,
              onTap: onOpenCreditors,
            ),
            _LaunchCard(
              title: 'Storefront Website',
              description:
                  'Edit products and prices shown on toufic-cell-stream.web.app.',
              icon: Icons.storefront_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StorefrontManagementScreen(),
                  ),
                );
              },
            ),
            _LaunchCard(
              title: 'Users and Passwords',
              description:
                  'Manage accounts and change any user or admin password.',
              icon: Icons.manage_accounts_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UserManagementScreen(),
                  ),
                );
              },
            ),
            _LaunchCard(
              title: 'Currency Settings',
              description: 'Set the USD → LBP rate shown across the app.',
              icon: Icons.currency_exchange_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CurrencySettingsScreen(),
                  ),
                );
              },
            ),
          ]
        : <_LaunchCard>[
            _LaunchCard(
              title: 'Debtors',
              description:
                  'Track balances and payments from the current debtor workflow.',
              icon: Icons.people_alt_rounded,
              onTap: onOpenDebtors,
            ),
          ];

    return ListView(
      children: [
        Text(
          isAdmin ? 'Admin Tools' : 'More',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          isAdmin
              ? 'Keep existing operational screens available without crowding the main navigation.'
              : 'Access supporting workflows while keeping Home and Products as the primary tabs.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 152,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) => tiles[index],
        ),
      ],
    );
  }
}

class _StorePulsePanel extends StatelessWidget {
  const _StorePulsePanel({required this.notes});

  final List<AdminNote> notes;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = NumberFormat.currency(symbol: r'$');

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Pulse',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MiniStatCard(
                    label: 'Products',
                    value: provider.totalProducts.toString(),
                  ),
                  const SizedBox(height: 12),
                  _MiniStatCard(
                    label: 'Low/out of stock',
                    value:
                        (provider.lowStockProducts +
                                provider.outOfStockProducts)
                            .toString(),
                    onTap: () => _showLowStockDialog(context, provider),
                  ),
                  const SizedBox(height: 12),
                  _MiniStatCard(
                    label: 'Month sales',
                    value: currency.format(provider.monthSalesAmount),
                    secondaryValue: formatLbp(
                      provider.monthSalesAmount,
                      provider.usdToLbpRate,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest Note',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (notes.isEmpty)
                      const Text('No admin notes yet.')
                    else ...[
                      Text(
                        notes.first.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notes.first.message,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({
    required this.isAdmin,
    required this.onOpenDebtors,
    required this.onOpenCreditors,
  });

  final bool isAdmin;
  final VoidCallback onOpenDebtors;
  final VoidCallback onOpenCreditors;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickActionData>[
      _QuickActionData(
        label: 'Debtors',
        icon: Icons.people_alt_rounded,
        onTap: onOpenDebtors,
      ),
      if (isAdmin)
        _QuickActionData(
          label: 'People I Owe',
          icon: Icons.handshake_outlined,
          onTap: onOpenCreditors,
        ),
      if (isAdmin)
        _QuickActionData(
          label: 'Manage Products',
          icon: Icons.inventory_2_rounded,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProductManagementScreen(),
              ),
            );
          },
        ),
      if (isAdmin)
        _QuickActionData(
          label: 'Maintenance',
          icon: Icons.build_circle_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MaintenanceManagementScreen(),
              ),
            );
          },
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep high-traffic store tasks within one tap.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: 170,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: action.onTap,
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(action.icon),
                              const SizedBox(height: 18),
                              Text(
                                action.label,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _LaunchCard extends StatelessWidget {
  const _LaunchCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    this.onTap,
    this.secondaryValue,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? secondaryValue;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 120),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (secondaryValue != null)
                  Text(
                    secondaryValue!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(22), child: Text(message)),
    );
  }
}

Future<void> _scanIntoSearch(
  BuildContext context,
  TextEditingController controller,
  ValueChanged<String> onChanged, [
  VoidCallback? onDone,
]) async {
  final value = await scanBarcode(context);
  if (value == null) {
    return;
  }
  controller.text = value;
  onChanged(value);
  onDone?.call();
}

void _showLowStockDialog(BuildContext context, AppProvider provider) {
  final lowStockProducts =
      provider.products
          .where((product) => product.isLowStock || product.isOutOfStock)
          .toList()
        ..sort((a, b) => a.quantity.compareTo(b.quantity));

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('Low / out-of-stock products (${lowStockProducts.length})'),
        content: SizedBox(
          width: 380,
          child: lowStockProducts.isEmpty
              ? const Text('No products are currently low or out of stock.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: lowStockProducts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = lowStockProducts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.name),
                      subtitle: Text(
                        product.categoryName.isEmpty
                            ? 'General inventory'
                            : product.categoryName,
                      ),
                      trailing: Text(
                        product.isOutOfStock
                            ? 'Out of stock'
                            : 'Low stock (${product.quantity})',
                        style: TextStyle(
                          color: product.isOutOfStock
                              ? Theme.of(context).colorScheme.error
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

String _displayUserLabel(AppProvider provider) {
  if (provider.currentUser == null) {
    return 'User';
  }
  if (provider.isAdmin) {
    return 'Admin';
  }
  final email = provider.currentUser!.email.trim();
  if (email.isEmpty || !email.contains('@')) {
    return 'User';
  }
  final localPart = email.split('@').first;
  return localPart.isEmpty
      ? 'User'
      : '${localPart[0].toUpperCase()}${localPart.substring(1)}';
}
