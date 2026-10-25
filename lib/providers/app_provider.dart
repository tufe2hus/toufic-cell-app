import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_note_model.dart';
import '../models/app_user.dart';
import '../models/bill_model.dart';
import '../models/business_record_models.dart';
import '../models/cart_item.dart';
import '../models/currency.dart';
import '../models/daily_profit_entry.dart';
import '../models/maintenance_job_model.dart';
import '../models/product_model.dart';
import '../models/shopping_list_item_model.dart';
import '../models/stock_intake_model.dart';
import '../models/storefront_models.dart';
import '../services/admin_note_service.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../services/category_service.dart';
import '../services/debtor_service.dart';
import '../services/maintenance_service.dart';
import '../services/payment_service.dart';
import '../services/product_service.dart';
import '../services/product_workflow_service.dart';
import '../services/sales_service.dart';
import '../services/settings_service.dart';
import '../services/shopping_list_service.dart';
import '../services/stock_intake_service.dart';
import '../services/storefront_service.dart';
import '../services/transaction_service.dart';
import '../services/user_service.dart';
import '../utils/phone_normalization.dart';

class CheckoutException implements Exception {
  const CheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CheckoutResult {
  const CheckoutResult({
    required this.invoiceNumber,
    required this.totalAmount,
    this.currency = Currency.usd,
  });

  final String invoiceNumber;
  final double totalAmount;
  final Currency currency;
}

class AppProvider extends ChangeNotifier {
  AppProvider({
    AuthService? authService,
    ProductService? productService,
    CategoryService? categoryService,
    SalesService? salesService,
    DebtorService? debtorService,
    TransactionService? transactionService,
    PaymentService? paymentService,
    UserService? userService,
    AdminNoteService? adminNoteService,
    BillService? billService,
    MaintenanceService? maintenanceService,
    SettingsService? settingsService,
    StorefrontService? storefrontService,
    StockIntakeService? stockIntakeService,
    ShoppingListService? shoppingListService,
  }) : _authService = authService ?? AuthService(),
       _productService = productService ?? ProductService(),
       _categoryService = categoryService ?? CategoryService(),
       _salesService = salesService ?? SalesService(),
       _debtorService = debtorService ?? DebtorService(),
       _transactionService = transactionService ?? TransactionService(),
       _paymentService = paymentService ?? PaymentService(),
       _userService = userService ?? UserService(),
       _adminNoteService = adminNoteService ?? AdminNoteService(),
       _billService = billService ?? BillService(),
       _maintenanceService = maintenanceService ?? MaintenanceService(),
       _settingsService = settingsService ?? SettingsService(),
       _storefrontService = storefrontService ?? StorefrontService(),
       _stockIntakeService = stockIntakeService ?? StockIntakeService(),
       _shoppingListService = shoppingListService ?? ShoppingListService(),
       _firestore = FirebaseFirestore.instance;

  final AuthService _authService;
  final ProductService _productService;
  final CategoryService _categoryService;
  final SalesService _salesService;
  final DebtorService _debtorService;
  final TransactionService _transactionService;
  final PaymentService _paymentService;
  final UserService _userService;
  final AdminNoteService _adminNoteService;
  final BillService _billService;
  final MaintenanceService _maintenanceService;
  final SettingsService _settingsService;
  final StockIntakeService _stockIntakeService;
  final StorefrontService _storefrontService;
  final ShoppingListService _shoppingListService;
  final FirebaseFirestore _firestore;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  AppUser? _currentUser;
  bool _isLoading = false;
  bool _hasAttemptedAuth = false;
  String? _errorMessage;
  ThemeMode _themeMode = ThemeMode.system;
  List<Product> _products = [];
  List<CategoryModel> _categories = [];
  List<SaleRecord> _sales = [];
  List<Debtor> _debtors = [];
  List<TransactionRecord> _transactions = [];
  List<PaymentRecord> _payments = [];
  List<AppUser> _users = [];
  List<AdminNote> _adminNotes = [];
  List<Bill> _bills = [];
  List<MaintenanceJob> _maintenanceJobs = [];
  List<ShoppingListItem> _shoppingListItems = [];
  double _usdToLbpRate = SettingsService.defaultUsdToLbpRate;
  List<StorefrontProduct> _storefrontProducts = [];
  List<StorefrontCategory> _storefrontCategories = [];
  StorefrontSettings _storefrontSettings = const StorefrontSettings();
  List<StockIntake> _stockIntakes = [];

  /// Sales whose parent transaction still exists, restricted to USD sales.
  /// Deleting a transaction (or any stray/orphaned sale left over from a
  /// past sync issue) removes it from every report figure below, so
  /// reports never show a total that includes something the store no
  /// longer considers a real sale. Restricting to USD keeps every $ report
  /// figure below internally consistent — an LBP-priced sale's amount
  /// (e.g. 1,500,000) must never be summed together with USD amounts (see
  /// requirement: USD and LBP are never auto-combined). LBP sales still
  /// exist in [_sales] and drive their debtor's own LBP ledger; they're
  /// simply excluded from these USD-denominated aggregate figures.
  List<SaleRecord> get _reportableSales {
    final validTransactionIds = _transactions.map((t) => t.id).toSet();
    return _sales
        .where(
          (sale) =>
              sale.currency == Currency.usd &&
              (sale.transactionId.isEmpty ||
                  validTransactionIds.contains(sale.transactionId)),
        )
        .toList();
  }

  Map<String, TransactionRecord> get _transactionsById => {
    for (final transaction in _transactions) transaction.id: transaction,
  };

  /// Profit from sales whose invoice was paid at checkout. A debt sale's
  /// profit is excluded here — it's counted separately via [_paymentProfit]
  /// once/as the linked debtor actually pays, dated by when it was paid
  /// rather than when it was sold.
  double _cashSaleProfit(Iterable<SaleRecord> sales) {
    final txById = _transactionsById;
    return sales.fold<double>(0, (total, sale) {
      final transaction = txById[sale.transactionId];
      if (transaction != null && transaction.paymentMethod == 'Debt') {
        return total;
      }
      return total + sale.profit;
    });
  }

  double _paymentProfit(Iterable<PaymentRecord> payments) => payments
      .where((payment) => payment.currency == Currency.usd)
      .fold<double>(0, (total, payment) => total + payment.profit);

  double _billsTotal(Iterable<Bill> bills) =>
      bills.fold<double>(0, (total, bill) => total + bill.amount);

  /// Maintenance/repair job profit is realized immediately (charged on the
  /// spot, like a cash sale) — USD-only, for the same reason as
  /// [_reportableSales]/[_paymentProfit].
  double _maintenanceProfit(Iterable<MaintenanceJob> jobs) => jobs
      .where((job) => job.currency == Currency.usd)
      .fold<double>(0, (total, job) => total + job.profit);

  // ── Unread-notes tracking ────────────────────────────────────────────────
  // The timestamp is persisted to SharedPreferences so it survives restarts.
  static const _prefKeyLastNotesReadAt = 'last_notes_read_at';
  DateTime? _lastNotesReadAt;
  bool _notesStreamInitialized = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get hasAttemptedAuth => _hasAttemptedAuth;
  String? get errorMessage => _errorMessage;
  ThemeMode get themeMode => _themeMode;
  List<Product> get products => _products;
  List<CategoryModel> get categories => _categories;
  List<SaleRecord> get sales => _sales;
  /// People who owe the store money (product/manual debts collected later).
  /// See [creditors] for the reverse — people/suppliers the store owes.
  List<Debtor> get debtors => _debtors.where((d) => d.theyOweMe).toList();
  /// People or suppliers the store owes money to — the reverse ledger of
  /// [debtors], sharing the same [Debtor] record shape and payment
  /// machinery (see [addManualDebt]'s `theyOweMe` and [recordPayment],
  /// which is symmetric: it just reduces whichever side's ledger).
  List<Debtor> get creditors => isAdmin
      ? _debtors.where((d) => !d.theyOweMe).toList()
      : const [];
  List<TransactionRecord> get transactions =>
      _transactions.isEmpty ? generatedTransactions : _transactions;
  List<PaymentRecord> get payments => _payments;
  List<AppUser> get users => _users;
  List<AdminNote> get adminNotes => _adminNotes;
  List<Bill> get bills => _bills;
  List<MaintenanceJob> get maintenanceJobs => _maintenanceJobs;
  List<ShoppingListItem> get shoppingListItems => _shoppingListItems;
  List<StorefrontProduct> get storefrontProducts => _storefrontProducts;
  List<StorefrontCategory> get storefrontCategories => _storefrontCategories;
  StorefrontSettings get storefrontSettings => _storefrontSettings;
  List<StockIntake> get stockIntakes => _stockIntakes;
  /// [StockIntake] entries whose [StockIntake.createdAt] falls in the
  /// calendar month containing [monthAnchor], newest first.
  List<StockIntake> stockIntakeForMonth(DateTime monthAnchor) {
    final entries = _stockIntakes
        .where(
          (intake) =>
              intake.createdAt.year == monthAnchor.year &&
              intake.createdAt.month == monthAnchor.month,
        )
        .toList();
    entries.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return entries;
  }

  double get usdToLbpRate => _usdToLbpRate;
  bool get isAdmin => currentUser?.isAdmin ?? false;
  bool get canManageProducts => isAdmin;
  bool get canManageCategories => isAdmin;
  bool get canViewProfits => isAdmin;
  bool get canViewPurchasePrices => isAdmin;
  bool get canAccessReports => isAdmin;
  bool get canApplyDiscount => isAdmin;
  bool get isOfflineDemoSession =>
      _currentUser?.uid.startsWith('offline-demo-') ?? false;
  String get currentActor =>
      currentUser?.email ?? currentUser?.uid ?? 'Unknown';
  int get totalProducts => _products.length;
  int get totalInventoryQuantity =>
      _products.fold<int>(0, (total, product) => total + product.quantity);
  int get lowStockProducts =>
      _products.where((product) => product.isLowStock).length;
  int get outOfStockProducts =>
      _products.where((product) => product.quantity <= 0).length;
  int get pendingDebtors =>
      debtors.where((debtor) => !debtor.isSettled).length;
  double get outstandingDebtAmount => debtors.fold<double>(
    0,
    (total, debtor) => total + debtor.remainingAmount,
  );
  int get pendingCreditors =>
      creditors.where((creditor) => !creditor.isSettled).length;
  double get outstandingCreditAmount => creditors.fold<double>(
    0,
    (total, creditor) => total + creditor.remainingAmount,
  );

  /// Number of admin notes created or updated after the user last opened the
  /// notes section.  Used to drive the notification badge on the Home tab.
  int get unreadNotesCount {
    if (_lastNotesReadAt == null) {
      return _adminNotes.length;
    }
    return _adminNotes
        .where((note) => note.updatedAt.isAfter(_lastNotesReadAt!))
        .length;
  }

  /// Call this when the user opens the Admin Notes section to reset the badge.
  Future<void> markNotesRead() async {
    _lastNotesReadAt = DateTime.now();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefKeyLastNotesReadAt,
        _lastNotesReadAt!.millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  // USD-only, for the same reason as `_reportableSales` above — an LBP
  // payment must never be summed into a USD figure.
  double get collectedToday {
    final today = DateTime.now();
    return _payments
        .where(
          (payment) =>
              payment.currency == Currency.usd &&
              _isSameDay(payment.paidAt, today),
        )
        .fold<double>(0, (total, payment) => total + payment.amount);
  }

  double get collectedThisMonth {
    final today = DateTime.now();
    return _payments
        .where(
          (payment) =>
              payment.currency == Currency.usd &&
              payment.paidAt.year == today.year &&
              payment.paidAt.month == today.month,
        )
        .fold<double>(0, (total, payment) => total + payment.amount);
  }

  double get todaySalesAmount => _salesInRange(
    days: 1,
  ).fold<double>(0, (total, sale) => total + sale.totalAmount);
  double get weekSalesAmount => _salesInRange(
    days: 7,
  ).fold<double>(0, (total, sale) => total + sale.totalAmount);
  double get monthSalesAmount => _reportableSales
      .where((sale) {
        final now = DateTime.now();
        return sale.soldAt.year == now.year && sale.soldAt.month == now.month;
      })
      .fold<double>(0, (total, sale) => total + sale.totalAmount);
  double get dailyProfit =>
      _cashSaleProfit(_salesInRange(days: 1)) +
      _paymentProfit(_paymentsInRange(days: 1)) +
      _maintenanceProfit(_maintenanceJobsInRange(days: 1)) -
      _billsTotal(_billsInRange(days: 1));
  double get weeklyProfit =>
      _cashSaleProfit(_salesInRange(days: 7)) +
      _paymentProfit(_paymentsInRange(days: 7)) +
      _maintenanceProfit(_maintenanceJobsInRange(days: 7)) -
      _billsTotal(_billsInRange(days: 7));
  /// This month's profit before subtracting paid bills/expenses — i.e. just
  /// sale margins realized so far (cash sales at sale time, debt sales as
  /// their debtor pays) plus maintenance job profit. See [monthlyProfit] for
  /// the figure after bills.
  double get monthlyProfitBeforeBills {
    final now = DateTime.now();
    final cashProfit = _cashSaleProfit(
      _reportableSales.where(
        (sale) =>
            sale.soldAt.year == now.year && sale.soldAt.month == now.month,
      ),
    );
    final paidProfit = _paymentProfit(
      _payments.where(
        (payment) =>
            payment.paidAt.year == now.year &&
            payment.paidAt.month == now.month,
      ),
    );
    final maintenanceProfit = _maintenanceProfit(
      _maintenanceJobs.where(
        (job) => job.date.year == now.year && job.date.month == now.month,
      ),
    );
    return cashProfit + paidProfit + maintenanceProfit;
  }

  double get monthlyProfit {
    final now = DateTime.now();
    final billsPaid = _billsTotal(
      _bills.where(
        (bill) => bill.paidAt.year == now.year && bill.paidAt.month == now.month,
      ),
    );
    return monthlyProfitBeforeBills - billsPaid;
  }

  double get yearlyProfit {
    final now = DateTime.now();
    final cashProfit = _cashSaleProfit(
      _reportableSales.where((sale) => sale.soldAt.year == now.year),
    );
    final paidProfit = _paymentProfit(
      _payments.where((payment) => payment.paidAt.year == now.year),
    );
    final maintenanceProfit = _maintenanceProfit(
      _maintenanceJobs.where((job) => job.date.year == now.year),
    );
    final billsPaid = _billsTotal(
      _bills.where((bill) => bill.paidAt.year == now.year),
    );
    return cashProfit + paidProfit + maintenanceProfit - billsPaid;
  }

  /// Sales/profit/product breakdown for one specific calendar day, computed
  /// live from the underlying sales/payments/bills records — shared by
  /// [dailyProfitSnapshot] (today-lookup card) and [dailyProfitForMonth]
  /// (the Reports screen's daily bar chart).
  DailyProfitEntry _dailyProfitEntry(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final salesInDay = _reportableSales
        .where(
          (sale) =>
              !sale.soldAt.isBefore(dayStart) && sale.soldAt.isBefore(dayEnd),
        )
        .toList();
    final paymentsInDay = _payments.where(
      (payment) =>
          !payment.paidAt.isBefore(dayStart) && payment.paidAt.isBefore(dayEnd),
    );
    final jobsInDay = _maintenanceJobs.where(
      (job) => !job.date.isBefore(dayStart) && job.date.isBefore(dayEnd),
    );
    final billsInDay = _bills.where(
      (bill) => !bill.paidAt.isBefore(dayStart) && bill.paidAt.isBefore(dayEnd),
    );

    final salesAmount = salesInDay.fold<double>(
      0,
      (total, sale) => total + sale.totalAmount,
    );
    final profitBeforeBills =
        _cashSaleProfit(salesInDay) +
        _paymentProfit(paymentsInDay) +
        _maintenanceProfit(jobsInDay);
    final profitAfterBills = profitBeforeBills - _billsTotal(billsInDay);

    final productTotals = <String, double>{};
    for (final sale in salesInDay) {
      productTotals[sale.productName] =
          (productTotals[sale.productName] ?? 0) + sale.totalAmount;
    }
    final productSales = Map.fromEntries(
      productTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return DailyProfitEntry(
      day: dayStart,
      salesAmount: salesAmount,
      profitBeforeBills: profitBeforeBills,
      profitAfterBills: profitAfterBills,
      productSales: productSales,
    );
  }

  /// Sales/profit for one specific calendar day — unlike [todaySalesAmount]
  /// and [dailyProfit] (which always mean "today"), this lets Reports look
  /// back at any past day even after midnight has rolled "today" over, since
  /// the source records stay in the database indefinitely.
  ({double salesAmount, double profitBeforeBills, double profitAfterBills})
  dailyProfitSnapshot(DateTime day) {
    final entry = _dailyProfitEntry(day);
    return (
      salesAmount: entry.salesAmount,
      profitBeforeBills: entry.profitBeforeBills,
      profitAfterBills: entry.profitAfterBills,
    );
  }

  /// One [DailyProfitEntry] per day of the calendar month containing
  /// [monthAnchor] (oldest first), for the Reports screen's daily-profit bar
  /// chart — each bar's tap target shows that day's product breakdown.
  List<DailyProfitEntry> dailyProfitForMonth(DateTime monthAnchor) {
    final daysInMonth = DateTime(
      monthAnchor.year,
      monthAnchor.month + 1,
      0,
    ).day;
    return [
      for (var day = 1; day <= daysInMonth; day++)
        _dailyProfitEntry(DateTime(monthAnchor.year, monthAnchor.month, day)),
    ];
  }

  List<SaleRecord> get recentSales => _sales.take(6).toList();
  List<TransactionRecord> get recentTransactions =>
      transactions.take(6).toList();
  List<SaleRecord> get currentUserSales => isAdmin
      ? _sales.take(6).toList()
      : _sales.where((sale) => sale.createdBy == currentActor).take(6).toList();
  List<TransactionRecord> get currentUserTransactions => isAdmin
      ? transactions.take(20).toList()
      : transactions
            .where((transaction) => transaction.createdBy == currentActor)
            .toList();
  List<TransactionRecord> get generatedTransactions =>
      _sales.take(20).map((sale) {
        return TransactionRecord(
          id: sale.id,
          invoiceNumber: sale.id.isEmpty
              ? 'INV-${sale.soldAt.millisecondsSinceEpoch}'
              : sale.id,
          customerName: 'Walk-in Customer',
          paymentMethod: 'Cash',
          productCount: sale.quantity,
          totalAmount: sale.totalAmount,
          profit: sale.profit,
          createdBy: sale.createdBy,
          createdAt: sale.soldAt,
          productNames: [sale.productName],
        );
      }).toList();

  void toggleThemeMode() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _hasAttemptedAuth = true;
    notifyListeners();

    final resolvedEmail = _resolveSignInEmail(username);

    try {
      UserCredential credential = await _authService.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );
      await _hydrateAndEnsureUserProfile(
        uid: credential.user!.uid,
        email: credential.user!.email ?? resolvedEmail,
      );
      await loadData();
    } on FirebaseAuthException catch (error) {
      if (_isAuthConfigurationError(error.code)) {
        _errorMessage =
            'Firebase Auth is not configured for this app yet '
            '(${error.code}). Enable Email/Password in Firebase Console '
            'for project storeapp-9dba6 and verify platform app configuration.';
        return;
      }

      _errorMessage = error.code == 'invalid-email'
          ? 'Enter a valid email address or username.'
          : error.toString();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _resolveSignInEmail(String username) {
    final normalizedUsername = username.trim().toLowerCase();
    if (!normalizedUsername.contains('@')) {
      return '$normalizedUsername@touficcell.com';
    }
    return username.trim();
  }

  Future<void> _hydrateAndEnsureUserProfile({
    required String uid,
    required String email,
  }) async {
    final existing = await _authService.getUserProfile(uid);
    final resolvedRole = existing?.role ?? 'user';

    if (existing == null) {
      await _authService.saveUserProfile(
        uid: uid,
        email: email,
        role: resolvedRole,
      );
      _currentUser = AppUser(
        uid: uid,
        email: email,
        role: resolvedRole,
        isActive: true,
        createdAt: DateTime.now(),
      );
      return;
    }

    if (!existing.isActive) {
      await _authService.signOut();
      throw StateError('This account has been deactivated. Contact an admin.');
    }
    _currentUser = existing;
  }

  bool _isAuthConfigurationError(String code) {
    return code == 'configuration-not-found' || code == 'operation-not-allowed';
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _products = [];
    _categories = [];
    _sales = [];
    _debtors = [];
    _transactions = [];
    _payments = [];
    _users = [];
    _adminNotes = [];
    _bills = [];
    _maintenanceJobs = [];
    _shoppingListItems = [];
    _storefrontProducts = [];
    _storefrontCategories = [];
    _storefrontSettings = const StorefrontSettings();
    _stockIntakes = [];
    _notesStreamInitialized = false;
    _lastNotesReadAt = null;
    notifyListeners();
  }

  Future<void> loadData() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _notesStreamInitialized = false;
    _isLoading = true;
    notifyListeners();

    // ── Load last-seen timestamp for notification badge ──────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefKeyLastNotesReadAt);
      if (ms != null) {
        _lastNotesReadAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {}

    // ── Offline demo sessions have no Firestore access ───────────────────────
    if (isOfflineDemoSession) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _subscriptions.add(
        (isAdmin
                ? _productService.productsStream()
                : _productService.publicProductsStream())
            .listen(
              (products) {
                _products = products;
                notifyListeners();
              },
              onError: (error) {
                debugPrint('Products stream error: $error');
                _errorMessage = 'Products stream failed: $error';
                notifyListeners();
              },
            ),
      );
      _subscriptions.add(
        _categoryService.categoriesStream().listen(
          (categories) {
            _categories = categories;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Categories stream error: $error');
            _errorMessage = 'Categories stream failed: $error';
            notifyListeners();
          },
        ),
      );
      _subscriptions.add(
        _settingsService.usdToLbpRateStream().listen(
          (rate) {
            _usdToLbpRate = rate;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Currency rate stream error: $error');
          },
        ),
      );
      _subscriptions.add(
        (isAdmin
                ? _salesService.salesStream()
                : _salesService.publicSalesStream())
            .listen(
              (sales) {
                _sales = sales;
                notifyListeners();
              },
              onError: (error) {
                debugPrint('Sales stream error: $error');
                _errorMessage = 'Sales stream failed: $error';
                notifyListeners();
              },
            ),
      );
      _subscriptions.add(
        _debtorService.debtorsStream().listen(
          (debtors) {
            _debtors = debtors;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Debtors stream error: $error');
            _errorMessage = 'Debtors stream failed: $error';
            notifyListeners();
          },
        ),
      );
      _subscriptions.add(
        (isAdmin
                ? _transactionService.transactionsStream()
                : _transactionService.publicTransactionsStream())
            .listen(
              (transactions) {
                _transactions = transactions;
                notifyListeners();
              },
              onError: (error) {
                debugPrint('Transactions stream error: $error');
                _errorMessage = 'Transactions stream failed: $error';
                notifyListeners();
              },
            ),
      );
      _subscriptions.add(
        _paymentService.paymentsStream().listen(
          (payments) {
            _payments = payments;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Payments stream error: $error');
            _errorMessage = 'Payments stream failed: $error';
            notifyListeners();
          },
        ),
      );
      if (isAdmin) {
        _subscriptions.add(
          _userService.usersStream().listen(
            (users) {
              _users = users;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Users stream error: $error');
              _errorMessage = 'Users stream failed: $error';
              notifyListeners();
            },
          ),
        );
        _subscriptions.add(
          _billService.billsStream().listen(
            (bills) {
              _bills = bills;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Bills stream error: $error');
              _errorMessage = 'Bills stream failed: $error';
              notifyListeners();
            },
          ),
        );
        _subscriptions.add(
          _maintenanceService.jobsStream().listen(
            (jobs) {
              _maintenanceJobs = jobs;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Maintenance jobs stream error: $error');
              _errorMessage = 'Maintenance jobs stream failed: $error';
              notifyListeners();
            },
          ),
        );
        _subscriptions.add(
          _shoppingListService.itemsStream().listen(
            (items) {
              _shoppingListItems = items;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Shopping list stream error: $error');
              _errorMessage = 'Shopping list stream failed: $error';
              notifyListeners();
            },
          ),
        );
        _subscriptions.add(
          _storefrontService.productsStream().listen(
            (products) {
              _storefrontProducts = products;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Storefront products stream error: $error');
              _errorMessage = 'Storefront products stream failed: $error';
              notifyListeners();
            },
          ),
        );
        _subscriptions.add(
          _storefrontService.categoriesStream().listen(
            (categories) {
              _storefrontCategories = categories;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Storefront categories stream error: $error');
              _errorMessage = 'Storefront categories stream failed: $error';
              notifyListeners();
            },
          ),
        );
        _subscriptions.add(
          _storefrontService.settingsStream().listen(
            (settings) {
              _storefrontSettings = settings;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Storefront settings stream error: $error');
              _errorMessage = 'Storefront settings stream failed: $error';
              notifyListeners();
            },
          ),
        );
        _subscriptions.add(
          _stockIntakeService.intakesStream().listen(
            (intakes) {
              _stockIntakes = intakes;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Stock intake stream error: $error');
              _errorMessage = 'Stock intake stream failed: $error';
              notifyListeners();
            },
          ),
        );
      }
      _subscriptions.add(
        _adminNoteService.notesStream().listen(
          (notes) {
            if (!_notesStreamInitialized) {
              // First emission: treat as initial state, no notification
              _notesStreamInitialized = true;
            }
            _adminNotes = notes;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Admin notes stream error: $error');
            _errorMessage = 'Admin notes stream failed: $error';
            notifyListeners();
          },
        ),
      );
    } catch (error) {
      debugPrint('loadData error: $error');
      _errorMessage = 'Failed to initialize live data: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createProduct(Product product) async {
    if (isOfflineDemoSession) {
      _createProductLocally(product);
      return;
    }
    await _productService.createProduct(product);
  }

  Future<void> updateProduct(Product product) async {
    if (isOfflineDemoSession) {
      _updateProductLocally(product);
      return;
    }
    await _productService.updateProduct(product);
  }

  Future<void> saveProduct({
    Product? existing,
    required String name,
    required String serialNumber,
    required String barcode,
    required String categoryId,
    required String purchasePrice,
    required String sellingPrice,
    required String quantity,
    String description = '',
    String? imageBase64,
    Currency currency = Currency.usd,
  }) async {
    final selectedCategory = categories.cast<CategoryModel?>().firstWhere(
      (category) => category?.id == categoryId,
      orElse: () => null,
    );
    if (selectedCategory == null) {
      throw StateError('Please select a valid category.');
    }

    final workflow = ProductWorkflowService(productService: _productService);
    final draft = ProductDraft(
      name: name,
      serialNumber: serialNumber,
      barcode: barcode,
      categoryId: categoryId,
      categoryName: selectedCategory.name,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      quantity: quantity,
      description: description,
      imageBase64: imageBase64,
      currency: currency,
    );

    if (isOfflineDemoSession) {
      workflow.validateProduct(
        draft: draft,
        existingProducts: _products,
        existingProductId: existing?.id,
      );

      final offlineProduct = workflow.buildProduct(
        draft: draft,
        productId: existing?.id ?? _productService.newProductId(),
        actor: currentUser?.email ?? '',
        existing: existing,
      );

      if (existing == null) {
        _createProductLocally(offlineProduct);
      } else {
        _updateProductLocally(offlineProduct);
      }
      await _logStockIntakeIfNeeded(
        existing: existing,
        productId: offlineProduct.id,
        productName: offlineProduct.name,
        categoryName: selectedCategory.name,
        newQuantity: offlineProduct.quantity,
        purchasePrice: offlineProduct.purchasePrice,
        currency: currency,
      );
      return;
    }

    final saved = await workflow.saveProduct(
      draft: draft,
      existingProducts: _products,
      actor: currentUser?.email ?? '',
      existing: existing,
    );
    await _logStockIntakeIfNeeded(
      existing: existing,
      productId: saved.id,
      productName: saved.name,
      categoryName: selectedCategory.name,
      newQuantity: saved.quantity,
      purchasePrice: saved.purchasePrice,
      currency: currency,
    );
  }

  /// Logs a [StockIntake] entry when [saveProduct] just created a brand-new
  /// product, or increased an existing one's quantity — never for a
  /// decrease (that's a correction, not new stock arriving). This is the
  /// only history of "what stock arrived and when"; a product's own
  /// `quantity` field only ever holds the current total.
  Future<void> _logStockIntakeIfNeeded({
    required Product? existing,
    required String productId,
    required String productName,
    required String categoryName,
    required int newQuantity,
    required double purchasePrice,
    required Currency currency,
  }) async {
    final previousQuantity = existing?.quantity ?? 0;
    final added = newQuantity - previousQuantity;
    if (added <= 0 || productId.isEmpty) {
      return;
    }
    final intake = StockIntake(
      id: _stockIntakeService.newIntakeId(),
      productId: productId,
      productName: productName,
      categoryName: categoryName,
      quantityAdded: added,
      purchasePrice: purchasePrice,
      currency: currency,
      isNewProduct: existing == null,
      createdBy: currentUser?.email ?? 'Unknown',
      createdAt: DateTime.now(),
    );
    if (isOfflineDemoSession) {
      _stockIntakes = [intake, ..._stockIntakes];
      notifyListeners();
      return;
    }
    await _stockIntakeService.createIntake(intake);
  }

  Future<void> createAdminNote({
    required String title,
    required String message,
    bool isImportant = false,
  }) async {
    final now = DateTime.now();
    final note = AdminNote(
      id: _adminNoteService.newNoteId(),
      title: title.trim(),
      message: message.trim(),
      createdBy: currentUser?.email ?? 'Admin',
      createdAt: now,
      updatedAt: now,
      isImportant: isImportant,
    );

    if (isOfflineDemoSession) {
      _adminNotes = [note, ..._adminNotes]
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      notifyListeners();
      return;
    }

    await _adminNoteService.createNote(note);
  }

  Future<void> updateAdminNote(
    AdminNote existing, {
    required String title,
    required String message,
    bool? isImportant,
  }) async {
    final updated = existing.copyWith(
      title: title.trim(),
      message: message.trim(),
      isImportant: isImportant ?? existing.isImportant,
      updatedAt: DateTime.now(),
      createdBy: currentUser?.email ?? existing.createdBy,
    );

    if (isOfflineDemoSession) {
      final notes = List<AdminNote>.from(_adminNotes);
      final index = notes.indexWhere((item) => item.id == existing.id);
      if (index == -1) {
        throw StateError('Note not found for update.');
      }
      notes[index] = updated;
      notes.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      _adminNotes = notes;
      notifyListeners();
      return;
    }

    await _adminNoteService.updateNote(updated);
  }

  Future<void> deleteAdminNote(AdminNote note) async {
    if (isOfflineDemoSession) {
      _adminNotes = _adminNotes.where((item) => item.id != note.id).toList();
      notifyListeners();
      return;
    }

    await _adminNoteService.deleteNote(note.id);
  }

  Future<void> createBill({
    required String name,
    required double amount,
    String note = '',
    DateTime? paidAt,
  }) async {
    final bill = Bill(
      id: _billService.newBillId(),
      name: name.trim(),
      amount: amount,
      note: note.trim(),
      paidAt: paidAt ?? DateTime.now(),
      paidBy: currentUser?.email ?? 'Admin',
    );

    if (isOfflineDemoSession) {
      _bills = [bill, ..._bills]
        ..sort((left, right) => right.paidAt.compareTo(left.paidAt));
      notifyListeners();
      return;
    }

    await _billService.createBill(bill);
  }

  Future<void> deleteBill(Bill bill) async {
    if (isOfflineDemoSession) {
      _bills = _bills.where((item) => item.id != bill.id).toList();
      notifyListeners();
      return;
    }

    await _billService.deleteBill(bill.id);
  }

  Future<void> createStorefrontProduct({
    required String name,
    required String description,
    required String logo,
    required double price,
    required String duration,
    String categoryId = '',
    int order = 0,
  }) async {
    final product = StorefrontProduct(
      id: _storefrontService.newProductId(),
      name: name.trim(),
      description: description.trim(),
      logo: logo.trim(),
      price: price,
      duration: duration.trim(),
      categoryId: categoryId,
      order: order,
    );
    if (isOfflineDemoSession) {
      _storefrontProducts = [..._storefrontProducts, product]
        ..sort((left, right) => left.order.compareTo(right.order));
      notifyListeners();
      return;
    }
    await _storefrontService.createProduct(product);
  }

  Future<void> updateStorefrontProduct(StorefrontProduct product) async {
    if (isOfflineDemoSession) {
      _storefrontProducts = [
        for (final item in _storefrontProducts)
          if (item.id == product.id) product else item,
      ]..sort((left, right) => left.order.compareTo(right.order));
      notifyListeners();
      return;
    }
    await _storefrontService.updateProduct(product);
  }

  Future<void> deleteStorefrontProduct(StorefrontProduct product) async {
    if (isOfflineDemoSession) {
      _storefrontProducts = _storefrontProducts
          .where((item) => item.id != product.id)
          .toList();
      notifyListeners();
      return;
    }
    await _storefrontService.deleteProduct(product.id);
  }

  Future<void> createStorefrontCategory({
    required String name,
    int order = 0,
  }) async {
    final category = StorefrontCategory(
      id: _storefrontService.newCategoryId(),
      name: name.trim(),
      order: order,
    );
    if (isOfflineDemoSession) {
      _storefrontCategories = [..._storefrontCategories, category]
        ..sort((left, right) => left.order.compareTo(right.order));
      notifyListeners();
      return;
    }
    await _storefrontService.createCategory(category);
  }

  Future<void> updateStorefrontCategory(StorefrontCategory category) async {
    if (isOfflineDemoSession) {
      _storefrontCategories = [
        for (final item in _storefrontCategories)
          if (item.id == category.id) category else item,
      ]..sort((left, right) => left.order.compareTo(right.order));
      notifyListeners();
      return;
    }
    await _storefrontService.updateCategory(category);
  }

  Future<void> deleteStorefrontCategory(StorefrontCategory category) async {
    if (isOfflineDemoSession) {
      _storefrontCategories = _storefrontCategories
          .where((item) => item.id != category.id)
          .toList();
      _storefrontProducts = [
        for (final product in _storefrontProducts)
          if (product.categoryId == category.id)
            StorefrontProduct(
              id: product.id,
              name: product.name,
              description: product.description,
              logo: product.logo,
              price: product.price,
              duration: product.duration,
              order: product.order,
              isActive: product.isActive,
            )
          else
            product,
      ];
      notifyListeners();
      return;
    }
    await _storefrontService.deleteCategory(category.id);
  }

  Future<void> updateStorefrontSettings(StorefrontSettings settings) async {
    if (isOfflineDemoSession) {
      _storefrontSettings = settings;
      notifyListeners();
      return;
    }
    await _storefrontService.updateSettings(settings);
  }

  Future<void> createMaintenanceJob({
    required String customerName,
    required String customerPhone,
    required String deviceDescription,
    required String workDescription,
    required double purchasePrice,
    required double sellingPrice,
    Currency currency = Currency.usd,
    String note = '',
    DateTime? date,
  }) async {
    final job = MaintenanceJob(
      id: _maintenanceService.newJobId(),
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim(),
      deviceDescription: deviceDescription.trim(),
      workDescription: workDescription.trim(),
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      // No date picked → default to the day the job is actually logged.
      date: date ?? DateTime.now(),
      createdBy: currentActor,
      currency: currency,
      note: note.trim(),
    );

    if (isOfflineDemoSession) {
      _maintenanceJobs = [job, ..._maintenanceJobs]
        ..sort((left, right) => right.date.compareTo(left.date));
      notifyListeners();
      return;
    }

    await _maintenanceService.createJob(job);
  }

  Future<void> deleteMaintenanceJob(MaintenanceJob job) async {
    if (isOfflineDemoSession) {
      _maintenanceJobs = _maintenanceJobs
          .where((item) => item.id != job.id)
          .toList();
      notifyListeners();
      return;
    }

    await _maintenanceService.deleteJob(job.id);
  }

  Future<void> createShoppingListItem({
    required String name,
    int quantity = 1,
    String note = '',
  }) async {
    final item = ShoppingListItem(
      id: _shoppingListService.newItemId(),
      name: name.trim(),
      quantity: quantity,
      note: note.trim(),
      createdAt: DateTime.now(),
      createdBy: currentActor,
    );

    if (isOfflineDemoSession) {
      _shoppingListItems = [item, ..._shoppingListItems];
      notifyListeners();
      return;
    }

    await _shoppingListService.createItem(item);
  }

  Future<void> setShoppingListItemBought(
    ShoppingListItem item,
    bool isBought,
  ) async {
    if (isOfflineDemoSession) {
      _shoppingListItems = _shoppingListItems
          .map((i) => i.id == item.id ? i.copyWith(isBought: isBought) : i)
          .toList();
      notifyListeners();
      return;
    }

    await _shoppingListService.setBought(item.id, isBought);
  }

  Future<void> deleteShoppingListItem(ShoppingListItem item) async {
    if (isOfflineDemoSession) {
      _shoppingListItems = _shoppingListItems
          .where((i) => i.id != item.id)
          .toList();
      notifyListeners();
      return;
    }

    await _shoppingListService.deleteItem(item.id);
  }

  /// Logs a one-off sale of an item that isn't tracked in inventory — e.g. a
  /// single unit the store only has once and doesn't want a permanent
  /// product record for. It records a cash sale or debtor invoice without
  /// touching product stock.
  Future<void> createQuickSale({
    required String productName,
    required double costPrice,
    required double sellingPrice,
    Currency currency = Currency.usd,
    String customerName = 'Walk-in Customer',
    String customerPhone = '',
    bool asDebt = false,
  }) async {
    final trimmedName = productName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Product name is required.');
    }
    if (sellingPrice <= 0) {
      throw ArgumentError('Selling price must be greater than zero.');
    }
    if (asDebt && customerName.trim().isEmpty) {
      throw ArgumentError('Customer name is required for a debt sale.');
    }
    final profit = sellingPrice - costPrice;
    final now = DateTime.now();
    final trimmedCustomerName = customerName.trim().isEmpty
        ? 'Walk-in Customer'
        : customerName.trim();
    final normalizedPhone = normalizeLebanesePhone(customerPhone);

    if (isOfflineDemoSession) {
      final transactionId = now.microsecondsSinceEpoch.toString();
      final sale = SaleRecord(
        id: '$transactionId-0',
        productName: trimmedName,
        serialNumber: '',
        categoryName: 'Quick sale',
        quantity: 1,
        unitPrice: sellingPrice,
        totalAmount: sellingPrice,
        discount: 0,
        profit: profit,
        soldAt: now,
        createdBy: currentActor,
        transactionId: transactionId,
        productId: '',
        currency: currency,
      );
      final transaction = TransactionRecord(
        id: transactionId,
        invoiceNumber: 'INV-${transactionId.substring(0, 8).toUpperCase()}',
        customerName: trimmedCustomerName,
        customerPhone: customerPhone,
        paymentMethod: asDebt ? 'Debt' : 'Cash',
        productCount: 1,
        totalAmount: sellingPrice,
        profit: profit,
        profitRealized: asDebt ? 0 : profit,
        createdBy: currentActor,
        createdAt: now,
        productNames: [trimmedName],
        currency: currency,
      );
      _sales = [sale, ..._sales];
      _transactions = [transaction, ..._transactions];
      if (asDebt) {
        _addManualDebtOffline(
          customerName: trimmedCustomerName,
          customerPhone: customerPhone,
          normalizedPhone: normalizedPhone,
          amount: sellingPrice,
          currency: currency,
          note: 'Quick sale: $trimmedName',
          dueDate: null,
          amountPaidNow: 0,
        );
      }
      notifyListeners();
      return;
    }

    final salesRef = _firestore.collection('sales');
    final salesPublicRef = _firestore.collection('sales_public');
    final transactionsRef = _firestore.collection('transactions');
    final transactionsPublicRef = _firestore.collection('transactions_public');

    final transactionRef = transactionsRef.doc();
    final transactionId = transactionRef.id;
    final saleRef = salesRef.doc();

    final sale = SaleRecord(
      id: saleRef.id,
      productName: trimmedName,
      serialNumber: '',
      categoryName: 'Quick sale',
      quantity: 1,
      unitPrice: sellingPrice,
      totalAmount: sellingPrice,
      discount: 0,
      profit: profit,
      soldAt: now,
      createdBy: currentActor,
      transactionId: transactionId,
      productId: '',
      currency: currency,
    );
    await _firestore.runTransaction((txn) async {
      DocumentReference<Map<String, dynamic>>? debtorRef;
      Debtor? existingDebtor;
      if (asDebt) {
        debtorRef = await _resolveDebtorRef(
          transaction: txn,
          normalizedPhone: normalizedPhone,
        );
        final snapshot = await txn.get(debtorRef);
        if (snapshot.exists) {
          existingDebtor = Debtor.fromMap(snapshot.data()!, debtorRef.id);
        }
      }

      final transaction = TransactionRecord(
        id: transactionId,
        invoiceNumber: 'INV-${transactionId.substring(0, 8).toUpperCase()}',
        customerName: trimmedCustomerName,
        customerPhone: customerPhone,
        paymentMethod: asDebt ? 'Debt' : 'Cash',
        productCount: 1,
        totalAmount: sellingPrice,
        profit: profit,
        profitRealized: asDebt ? 0 : profit,
        createdBy: currentActor,
        createdAt: now,
        productNames: [trimmedName],
        currency: currency,
      );

      txn.set(
        saleRef,
        sale.toMap()..['soldAt'] = FieldValue.serverTimestamp(),
      );
      txn.set(
        salesPublicRef.doc(saleRef.id),
        sale.toPublicMap()..['soldAt'] = FieldValue.serverTimestamp(),
      );
      txn.set(
        transactionRef,
        transaction.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
      );
      txn.set(
        transactionsPublicRef.doc(transactionId),
        transaction.toPublicMap()..['createdAt'] = FieldValue.serverTimestamp(),
      );

      if (debtorRef != null) {
        final debtor = Debtor(
          id: debtorRef.id,
          name: trimmedCustomerName,
          phoneNumber: customerPhone,
          normalizedPhone: normalizedPhone,
          note: 'Quick sale: $trimmedName',
          createdAt: existingDebtor?.createdAt ?? now,
          theyOweMe: true,
          usdTotalDebtCents: currency == Currency.usd
              ? (existingDebtor?.usdTotalDebtCents ?? 0) +
                    currency.toMinorUnits(sellingPrice)
              : (existingDebtor?.usdTotalDebtCents ?? 0),
          usdTotalPaidCents: existingDebtor?.usdTotalPaidCents ?? 0,
          lbpTotalDebt: currency == Currency.lbp
              ? (existingDebtor?.lbpTotalDebt ?? 0) +
                    currency.toMinorUnits(sellingPrice)
              : (existingDebtor?.lbpTotalDebt ?? 0),
          lbpTotalPaid: existingDebtor?.lbpTotalPaid ?? 0,
          dueDate: existingDebtor?.dueDate,
          invoiceCount: (existingDebtor?.invoiceCount ?? 0) + 1,
          updatedAt: now,
          lastPaymentAt: existingDebtor?.lastPaymentAt,
          createdBy: existingDebtor?.createdBy.isNotEmpty == true
              ? existingDebtor!.createdBy
              : currentActor,
        );
        txn.set(debtorRef, debtor.toMap(), SetOptions(merge: true));
        if (normalizedPhone.isNotEmpty) {
          txn.set(_debtorService.phoneIndexRef.doc(normalizedPhone), {
            'debtorId': debtorRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        final historyRef = _debtorService.transactionsRef(debtorRef.id).doc();
        txn.set(
          historyRef,
          DebtorTransaction(
            id: historyRef.id,
            type: 'debt',
            currency: currency,
            createdBy: currentActor,
            createdAt: now,
            subtotal: sellingPrice,
            finalTotal: sellingPrice,
            remainingBalanceAfter: sellingPrice,
            note: 'Quick sale: $trimmedName',
            linkedTransactionId: transactionId,
            profitCents: currency.toMinorUnits(profit),
            profitRealizedCents: 0,
          ).toMap(),
        );
      }
    });
  }

  Future<void> updateUsdToLbpRate(double rate) async {
    if (rate <= 0) {
      throw ArgumentError('Exchange rate must be greater than zero.');
    }

    if (isOfflineDemoSession) {
      _usdToLbpRate = rate;
      notifyListeners();
      return;
    }

    await _settingsService.updateUsdToLbpRate(rate);
  }

  Future<void> deleteProduct(String id) async {
    if (isOfflineDemoSession) {
      _products = _products.where((product) => product.id != id).toList();
      notifyListeners();
      return;
    }
    await _productService.deleteProduct(id);
  }

  void _createProductLocally(Product product) {
    final normalizedBarcode = product.barcode.trim().toLowerCase();
    final normalizedSerial = product.serialNumber.trim().toLowerCase();
    final barcodeExists =
        normalizedBarcode.isNotEmpty &&
        _products.any(
          (item) => item.barcode.trim().toLowerCase() == normalizedBarcode,
        );
    if (barcodeExists) {
      throw StateError('Barcode already exists.');
    }
    final serialExists =
        normalizedSerial.isNotEmpty &&
        _products.any(
          (item) => item.serialNumber.trim().toLowerCase() == normalizedSerial,
        );
    if (serialExists) {
      throw StateError('Serial number already exists.');
    }
    _products = [product, ..._products];
    notifyListeners();
  }

  void _updateProductLocally(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      throw StateError('Product not found for update.');
    }
    final normalizedBarcode = product.barcode.trim().toLowerCase();
    final normalizedSerial = product.serialNumber.trim().toLowerCase();
    final barcodeExists =
        normalizedBarcode.isNotEmpty &&
        _products.any(
          (item) =>
              item.id != product.id &&
              item.barcode.trim().toLowerCase() == normalizedBarcode,
        );
    if (barcodeExists) {
      throw StateError('Barcode already exists.');
    }
    final serialExists =
        normalizedSerial.isNotEmpty &&
        _products.any(
          (item) =>
              item.id != product.id &&
              item.serialNumber.trim().toLowerCase() == normalizedSerial,
        );
    if (serialExists) {
      throw StateError('Serial number already exists.');
    }
    final updated = List<Product>.from(_products);
    updated[index] = product;
    _products = updated;
    notifyListeners();
  }

  Future<void> createCategory(CategoryModel category) async {
    await _categoryService.createCategory(category);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _categoryService.updateCategory(category);
  }

  Future<void> deleteCategory(String id) async {
    await _categoryService.deleteCategory(id);
  }

  Future<void> createDebtor(Debtor debtor) async {
    await _debtorService.createDebtor(debtor);
  }

  Future<void> updateDebtor(Debtor debtor) async {
    await _debtorService.updateDebtor(debtor);
  }

  /// Permanently deletes a debtor: removes their profile and full
  /// transaction history, and restores stock for every product that was
  /// taken as part of a debt entry (paid or not) — no debt/payment math is
  /// performed, the record is simply erased and the goods come back.
  Future<void> deleteDebtor(Debtor debtor) async {
    if (isOfflineDemoSession) {
      _deleteDebtorOffline(debtor);
      return;
    }
    await _deleteDebtorOnline(debtor);
  }

  void _deleteDebtorOffline(Debtor debtor) {
    _debtors = _debtors.where((item) => item.id != debtor.id).toList();
    notifyListeners();
  }

  Future<void> _deleteDebtorOnline(Debtor debtor) async {
    final productsRef = _firestore.collection('products');
    final productCatalogRef = _firestore.collection('product_catalog');
    final debtorRef = _firestore.collection('debtors').doc(debtor.id);
    final entriesRef = _debtorService.transactionsRef(debtor.id);

    // Firestore transactions can't run queries, so read every history entry
    // first (to know which products to restock), then delete everything
    // (and restore stock) atomically below.
    final entriesSnapshot = await entriesRef.get();

    final restoreByProduct = <String, int>{};
    for (final doc in entriesSnapshot.docs) {
      final data = doc.data();
      if (data['type'] != 'debt') continue;
      final rawProducts = data['products'];
      if (rawProducts is! List) continue;
      for (final item in rawProducts) {
        if (item is! Map) continue;
        final productId = item['productId'] as String? ?? '';
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId.isEmpty || quantity <= 0) continue;
        restoreByProduct[productId] =
            (restoreByProduct[productId] ?? 0) + quantity;
      }
    }

    final phoneIndexRef = debtor.normalizedPhone.isEmpty
        ? null
        : _debtorService.phoneIndexRef.doc(debtor.normalizedPhone);

    await _firestore.runTransaction((txn) async {
      final freshProducts = <String, Product>{};
      for (final productId in restoreByProduct.keys) {
        final snapshot = await txn.get(productsRef.doc(productId));
        if (snapshot.exists) {
          freshProducts[productId] = Product.fromMap(
            snapshot.data() ?? <String, dynamic>{},
            snapshot.id,
          );
        }
      }

      DocumentSnapshot<Map<String, dynamic>>? phoneIndexSnapshot;
      if (phoneIndexRef != null) {
        phoneIndexSnapshot = await txn.get(phoneIndexRef);
      }

      for (final entry in restoreByProduct.entries) {
        final fresh = freshProducts[entry.key];
        if (fresh == null) continue;
        final restoredQuantity = fresh.quantity + entry.value;
        final stockUpdate = {
          'quantity': restoredQuantity,
          'stock': restoredQuantity,
          'isSold': restoredQuantity <= 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        txn.update(productsRef.doc(entry.key), stockUpdate);
        txn.set(
          productCatalogRef.doc(entry.key),
          stockUpdate,
          SetOptions(merge: true),
        );
      }

      for (final doc in entriesSnapshot.docs) {
        txn.delete(doc.reference);
      }

      if (phoneIndexRef != null &&
          phoneIndexSnapshot != null &&
          phoneIndexSnapshot.data()?['debtorId'] == debtor.id) {
        txn.delete(phoneIndexRef);
      }

      txn.delete(debtorRef);
    });
  }

  /// Detailed per-event history for one debtor's profile (products taken,
  /// debt added, payments received) — oldest first.
  Stream<List<DebtorTransaction>> debtorTransactionsStream(String debtorId) =>
      _debtorService.debtorTransactionsStream(debtorId);

  /// Finds the debtor matching [normalizedPhone] via the phone index (read
  /// inside [transaction], so the lookup is atomic and race-free against
  /// concurrent debtor creation from another device), or allocates a new
  /// debtor id if none exists yet / no phone was given (no dedup is
  /// possible without a phone number). Must be called before any writes in
  /// the caller's transaction.
  Future<DocumentReference<Map<String, dynamic>>> _resolveDebtorRef({
    required Transaction transaction,
    required String normalizedPhone,
    String? existingDebtorId,
  }) async {
    final debtorsRef = _firestore.collection('debtors');
    if (existingDebtorId != null && existingDebtorId.isNotEmpty) {
      return debtorsRef.doc(existingDebtorId);
    }
    if (normalizedPhone.isEmpty) {
      return debtorsRef.doc();
    }
    final indexRef = _debtorService.phoneIndexRef.doc(normalizedPhone);
    final indexSnapshot = await transaction.get(indexRef);
    final existingId = indexSnapshot.data()?['debtorId'] as String?;
    if (existingId != null && existingId.isNotEmpty) {
      return debtorsRef.doc(existingId);
    }
    return debtorsRef.doc();
  }

  /// Records a payment against [debtor], reducing only its [currency]
  /// balance (a USD payment never touches the LBP ledger, and vice versa).
  /// Guarded against double-submission by [payment]'s own id (checked for
  /// prior existence as the very first read inside the transaction).
  /// Profit on any linked product-sale debts is realized oldest-debt-first
  /// as payments come in, so reports only count profit once it's actually
  /// been collected.
  Future<void> recordPayment(
    PaymentRecord payment,
    Debtor debtor, {
    Currency currency = Currency.usd,
  }) async {
    final paymentMinorUnits = currency.toMinorUnits(payment.amount);
    if (paymentMinorUnits <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    if (isOfflineDemoSession) {
      _recordPaymentOffline(payment, debtor, currency, paymentMinorUnits);
      return;
    }

    final debtorRef = _firestore.collection('debtors').doc(debtor.id);
    final paymentRef = _firestore.collection('payments').doc(payment.id);
    final debtEntriesRef = _debtorService.transactionsRef(debtor.id);
    final historyEntryRef = debtEntriesRef.doc();

    // Firestore transactions can't run queries, so figure out which debt
    // entries exist for this debtor/currency *before* opening the
    // transaction (a plain read, not part of the atomic write), then
    // re-fetch each candidate by direct reference inside the transaction
    // below for a consistent, race-free view at write time.
    final allEntries = await debtEntriesRef.orderBy('createdAt').get();
    final candidateRefs = [
      for (final doc in allEntries.docs)
        if (doc.data()['type'] == 'debt' &&
            doc.data()['currency'] == currency.storageValue)
          debtEntriesRef.doc(doc.id),
    ];

    await _firestore.runTransaction((transaction) async {
      final debtorSnapshot = await transaction.get(debtorRef);
      if (!debtorSnapshot.exists) {
        throw StateError('Debtor not found.');
      }
      final paymentSnapshot = await transaction.get(paymentRef);
      if (paymentSnapshot.exists) {
        throw StateError('This payment has already been recorded.');
      }
      final debtEntrySnapshots = [
        for (final ref in candidateRefs) await transaction.get(ref),
      ];

      final existing = Debtor.fromMap(
        debtorSnapshot.data() ?? <String, dynamic>{},
        debtor.id,
      );
      final totalDebtMinor = currency == Currency.usd
          ? existing.usdTotalDebtCents
          : existing.lbpTotalDebt;
      final currentPaidMinor = currency == Currency.usd
          ? existing.usdTotalPaidCents
          : existing.lbpTotalPaid;
      final newTotalPaidMinor = currentPaidMinor + paymentMinorUnits;
      final remainingMinor = totalDebtMinor - newTotalPaidMinor;
      if (remainingMinor < 0) {
        throw StateError(
          'Payment exceeds remaining ${currency.name.toUpperCase()} debt.',
        );
      }

      // Allocate this payment across outstanding debt entries oldest-first,
      // realizing each one's profit proportionally to how much of it this
      // payment pays off (clamped so a final payment always closes a debt
      // entry out exactly, regardless of rounding drift).
      var remainingForAllocation = paymentMinorUnits;
      var totalProfitRealizedNow = 0;
      final debtEntryUpdates =
          <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
      for (var i = 0; i < debtEntrySnapshots.length; i++) {
        if (remainingForAllocation <= 0) break;
        final snapshot = debtEntrySnapshots[i];
        if (!snapshot.exists) continue;
        final entry = DebtorTransaction.fromMap(snapshot.data()!, snapshot.id);
        final entryFinalMinor = currency.toMinorUnits(entry.finalTotal);
        final entryPaidMinor = currency.toMinorUnits(entry.paidAmount);
        final entryOutstandingMinor = entryFinalMinor > entryPaidMinor
            ? entryFinalMinor - entryPaidMinor
            : 0;
        if (entryOutstandingMinor <= 0) continue;

        final appliedMinor = remainingForAllocation < entryOutstandingMinor
            ? remainingForAllocation
            : entryOutstandingMinor;
        remainingForAllocation -= appliedMinor;
        final newEntryPaidMinor = entryPaidMinor + appliedMinor;

        var newRealizedCents = entry.profitRealizedCents;
        if (entry.profitCents > 0) {
          final fullyPaid = newEntryPaidMinor >= entryFinalMinor;
          final rawTarget = fullyPaid
              ? entry.profitCents
              : (entry.profitCents * newEntryPaidMinor / entryFinalMinor)
                    .round();
          newRealizedCents = rawTarget < entry.profitRealizedCents
              ? entry.profitRealizedCents
              : (rawTarget > entry.profitCents ? entry.profitCents : rawTarget);
        }
        totalProfitRealizedNow += newRealizedCents - entry.profitRealizedCents;

        debtEntryUpdates[candidateRefs[i]] = {
          'paidAmount': currency.fromMinorUnits(newEntryPaidMinor),
          'profitRealizedCents': newRealizedCents,
        };
      }

      final now = DateTime.now();

      final paymentPayload = payment.toMap();
      paymentPayload['amount'] = currency.fromMinorUnits(paymentMinorUnits);
      paymentPayload['amountCents'] =
          currency == Currency.usd ? paymentMinorUnits : 0;
      paymentPayload['currency'] = currency.storageValue;
      paymentPayload['status'] = 'completed';
      paymentPayload['updatedAt'] = now;
      // Store the balance AFTER this payment so the history dialog can display it.
      paymentPayload['remainingAfter'] = currency.fromMinorUnits(remainingMinor);
      paymentPayload['profit'] = currency.fromMinorUnits(totalProfitRealizedNow);
      transaction.set(paymentRef, paymentPayload);

      final debtorUpdate = <String, dynamic>{
        'updatedAt': now,
        'lastPaymentAt': now,
      };
      if (currency == Currency.usd) {
        debtorUpdate.addAll({
          'usdTotalPaidCents': newTotalPaidMinor,
          'paidAmount': newTotalPaidMinor / 100.0,
          'totalPaid': newTotalPaidMinor / 100.0,
          'totalPaidCents': newTotalPaidMinor,
          'remainingDebt': remainingMinor / 100.0,
        });
      } else {
        debtorUpdate['lbpTotalPaid'] = newTotalPaidMinor;
      }
      transaction.update(debtorRef, debtorUpdate);

      transaction.set(
        historyEntryRef,
        DebtorTransaction(
          id: historyEntryRef.id,
          type: 'payment',
          currency: currency,
          createdBy: payment.receivedBy,
          createdAt: now,
          paidAmount: currency.fromMinorUnits(paymentMinorUnits),
          remainingBalanceAfter: currency.fromMinorUnits(remainingMinor),
          note: payment.note,
        ).toMap()..['createdAt'] = now,
      );

      debtEntryUpdates.forEach(
        (ref, data) => transaction.update(ref, data),
      );
    });
  }

  void _recordPaymentOffline(
    PaymentRecord payment,
    Debtor debtor,
    Currency currency,
    int paymentMinorUnits,
  ) {
    final index = _debtors.indexWhere((item) => item.id == debtor.id);
    if (index == -1) {
      throw StateError('Debtor not found.');
    }
    final existing = _debtors[index];
    final totalDebtMinor = currency == Currency.usd
        ? existing.usdTotalDebtCents
        : existing.lbpTotalDebt;
    final currentPaidMinor = currency == Currency.usd
        ? existing.usdTotalPaidCents
        : existing.lbpTotalPaid;
    final newTotalPaidMinor = currentPaidMinor + paymentMinorUnits;
    if (newTotalPaidMinor > totalDebtMinor) {
      throw StateError(
        'Payment exceeds remaining ${currency.name.toUpperCase()} debt.',
      );
    }
    final now = DateTime.now();
    final updated = Debtor(
      id: existing.id,
      name: existing.name,
      phoneNumber: existing.phoneNumber,
      normalizedPhone: existing.normalizedPhone,
      note: existing.note,
      createdAt: existing.createdAt,
      theyOweMe: existing.theyOweMe,
      usdTotalDebtCents: existing.usdTotalDebtCents,
      usdTotalPaidCents: currency == Currency.usd
          ? newTotalPaidMinor
          : existing.usdTotalPaidCents,
      lbpTotalDebt: existing.lbpTotalDebt,
      lbpTotalPaid: currency == Currency.lbp
          ? newTotalPaidMinor
          : existing.lbpTotalPaid,
      dueDate: existing.dueDate,
      invoiceCount: existing.invoiceCount,
      updatedAt: now,
      lastPaymentAt: now,
      createdBy: existing.createdBy,
    );
    final updatedList = List<Debtor>.from(_debtors);
    updatedList[index] = updated;
    _debtors = updatedList;
    notifyListeners();
  }

  /// Adds a debt not tied to specific products (a manually-entered amount),
  /// de-duplicating against an existing customer by phone number exactly
  /// like a product-based debt sale does (see [checkoutCart]).
  Future<void> addManualDebt({
    required String customerName,
    required String customerPhone,
    required double amount,
    Currency currency = Currency.usd,
    String note = '',
    DateTime? dueDate,
    double amountPaidNow = 0,
    double manualAdjustment = 0,
    /// Adds straight to this debtor instead of resolving by phone — used
    /// when the caller already knows exactly which debtor this is (e.g. the
    /// Debtors screen's "Add charge" flow), so a phoneless debtor doesn't
    /// end up split into a duplicate record.
    String? existingDebtorId,
    /// `true` (default) means this person owes the store money — a normal
    /// debtor. `false` means the store owes *them* — a creditor/supplier
    /// entry, tracked with the exact same ledger and [recordPayment] flow,
    /// just on the other side of who owes whom (see [creditors]).
    bool theyOweMe = true,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Debt amount must be greater than zero.');
    }
    final normalizedPhone = normalizeLebanesePhone(customerPhone);
    final rawFinalAmount = amount + manualAdjustment;
    final finalAmount = rawFinalAmount < 0 ? 0.0 : rawFinalAmount;
    final clampedPaidNow = amountPaidNow < 0
        ? 0.0
        : (amountPaidNow > finalAmount ? finalAmount : amountPaidNow);

    if (isOfflineDemoSession) {
      _addManualDebtOffline(
        customerName: customerName,
        customerPhone: customerPhone,
        normalizedPhone: normalizedPhone,
        amount: finalAmount,
        currency: currency,
        note: note,
        dueDate: dueDate,
        amountPaidNow: clampedPaidNow,
        existingDebtorId: existingDebtorId,
        theyOweMe: theyOweMe,
      );
      return;
    }

    await _firestore.runTransaction((txn) async {
      final debtorRef = await _resolveDebtorRef(
        transaction: txn,
        normalizedPhone: normalizedPhone,
        existingDebtorId: existingDebtorId,
      );
      final debtorSnapshot = await txn.get(debtorRef);
      final existingDebtor = debtorSnapshot.exists
          ? Debtor.fromMap(debtorSnapshot.data()!, debtorRef.id)
          : null;

      final now = DateTime.now();
      final amountMinor = currency.toMinorUnits(finalAmount);
      final paidNowMinor = currency.toMinorUnits(clampedPaidNow);
      final remainingMinor = amountMinor - paidNowMinor;

      final debtor = Debtor(
        id: debtorRef.id,
        name: customerName,
        phoneNumber: customerPhone,
        normalizedPhone: normalizedPhone,
        note: note,
        createdAt: existingDebtor?.createdAt ?? now,
        theyOweMe: theyOweMe,
        usdTotalDebtCents: currency == Currency.usd
            ? (existingDebtor?.usdTotalDebtCents ?? 0) + amountMinor
            : (existingDebtor?.usdTotalDebtCents ?? 0),
        usdTotalPaidCents: currency == Currency.usd
            ? (existingDebtor?.usdTotalPaidCents ?? 0) + paidNowMinor
            : (existingDebtor?.usdTotalPaidCents ?? 0),
        lbpTotalDebt: currency == Currency.lbp
            ? (existingDebtor?.lbpTotalDebt ?? 0) + amountMinor
            : (existingDebtor?.lbpTotalDebt ?? 0),
        lbpTotalPaid: currency == Currency.lbp
            ? (existingDebtor?.lbpTotalPaid ?? 0) + paidNowMinor
            : (existingDebtor?.lbpTotalPaid ?? 0),
        dueDate: dueDate ?? existingDebtor?.dueDate,
        invoiceCount: (existingDebtor?.invoiceCount ?? 0) + 1,
        updatedAt: now,
        lastPaymentAt: paidNowMinor > 0 ? now : existingDebtor?.lastPaymentAt,
        createdBy: existingDebtor?.createdBy.isNotEmpty == true
            ? existingDebtor!.createdBy
            : currentActor,
      );
      txn.set(debtorRef, debtor.toMap(), SetOptions(merge: true));

      if (normalizedPhone.isNotEmpty) {
        txn.set(_debtorService.phoneIndexRef.doc(normalizedPhone), {
          'debtorId': debtorRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final historyRef = _debtorService.transactionsRef(debtorRef.id).doc();
      txn.set(
        historyRef,
        DebtorTransaction(
          id: historyRef.id,
          type: 'debt',
          currency: currency,
          createdBy: currentActor,
          createdAt: now,
          subtotal: amount,
          manualAdjustment: manualAdjustment,
          finalTotal: finalAmount,
          paidAmount: clampedPaidNow,
          remainingBalanceAfter: currency.fromMinorUnits(remainingMinor),
          note: note,
        ).toMap(),
      );

      if (clampedPaidNow > 0) {
        final paymentRef = _firestore.collection('payments').doc();
        txn.set(
          paymentRef,
          PaymentRecord(
            id: paymentRef.id,
            debtorId: debtorRef.id,
            customerName: customerName,
            amount: clampedPaidNow,
            note: 'Paid at time of debt entry',
            receivedBy: currentActor,
            paidAt: now,
            currency: currency,
            remainingAfter: currency.fromMinorUnits(remainingMinor),
          ).toMap(),
        );
      }
    });
  }

  void _addManualDebtOffline({
    required String customerName,
    required String customerPhone,
    required String normalizedPhone,
    required double amount,
    required Currency currency,
    required String note,
    required DateTime? dueDate,
    required double amountPaidNow,
    String? existingDebtorId,
    bool theyOweMe = true,
  }) {
    final now = DateTime.now();
    final amountMinor = currency.toMinorUnits(amount);
    final paidNowMinor = currency.toMinorUnits(amountPaidNow);
    final matchIndex = existingDebtorId != null && existingDebtorId.isNotEmpty
        ? _debtors.indexWhere((d) => d.id == existingDebtorId)
        : (normalizedPhone.isEmpty
              ? -1
              : _debtors.indexWhere((d) => d.normalizedPhone == normalizedPhone));
    final existing = matchIndex == -1 ? null : _debtors[matchIndex];

    final debtor = Debtor(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: customerName,
      phoneNumber: customerPhone,
      normalizedPhone: normalizedPhone,
      note: note,
      createdAt: existing?.createdAt ?? now,
      theyOweMe: theyOweMe,
      usdTotalDebtCents: currency == Currency.usd
          ? (existing?.usdTotalDebtCents ?? 0) + amountMinor
          : (existing?.usdTotalDebtCents ?? 0),
      usdTotalPaidCents: currency == Currency.usd
          ? (existing?.usdTotalPaidCents ?? 0) + paidNowMinor
          : (existing?.usdTotalPaidCents ?? 0),
      lbpTotalDebt: currency == Currency.lbp
          ? (existing?.lbpTotalDebt ?? 0) + amountMinor
          : (existing?.lbpTotalDebt ?? 0),
      lbpTotalPaid: currency == Currency.lbp
          ? (existing?.lbpTotalPaid ?? 0) + paidNowMinor
          : (existing?.lbpTotalPaid ?? 0),
      dueDate: dueDate ?? existing?.dueDate,
      invoiceCount: (existing?.invoiceCount ?? 0) + 1,
      updatedAt: now,
      lastPaymentAt: paidNowMinor > 0 ? now : existing?.lastPaymentAt,
      createdBy: existing?.createdBy ?? currentActor,
    );

    if (matchIndex == -1) {
      _debtors = [debtor, ..._debtors];
    } else {
      final updated = List<Debtor>.from(_debtors);
      updated[matchIndex] = debtor;
      _debtors = updated;
    }
    notifyListeners();
  }

  Future<void> createTransaction(TransactionRecord transaction) async {
    await _transactionService.createTransaction(transaction);
  }

  Future<void> setUserActive(AppUser user, bool isActive) async {
    if (!isAdmin) {
      throw StateError('Only an admin can manage user accounts.');
    }
    if (user.uid == currentUser?.uid) {
      throw StateError('You cannot deactivate your own account.');
    }
    if (!isActive &&
        user.isAdmin &&
        _users.where((item) => item.isAdmin && item.isActive).length <= 1) {
      throw StateError('The last active admin account cannot be deactivated.');
    }
    if (isOfflineDemoSession) {
      throw StateError('User management is unavailable in offline demo mode.');
    }
    await _userService.setActive(user.uid, isActive);
  }

  /// Completes a multi-item sale, either paid in cash or, when [asDebt] is
  /// true, added as a debtor to be collected later. Stock is re-validated
  /// against Firestore atomically at write time, so the caller's cart
  /// snapshot may be stale without causing an oversell. A debt sale still
  /// decrements stock and records the invoice immediately — the goods left
  /// the store — but its profit is only counted in the profit reports once
  /// the resulting debtor actually pays (see [recordPayment]).
  Future<CheckoutResult> checkoutCart({
    required List<CartItem> items,
    String customerName = 'Walk-in Customer',
    bool asDebt = false,
    String customerPhone = '',
    DateTime? debtDueDate,
    String debtNote = '',
    double manualAdjustment = 0,
    double amountPaidNow = 0,
    String? idempotencyKey,
    /// Adds this debt straight to an already-known debtor instead of
    /// resolving one by phone (see [addManualDebt]'s `existingDebtorId`).
    String? existingDebtorId,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Cart is empty.');
    }

    final currency = items.first.product.currency;
    final hasMixedCurrency = items.any(
      (item) => item.product.currency != currency,
    );
    if (hasMixedCurrency) {
      throw const CheckoutException(
        'This sale mixes USD- and LBP-priced items. Complete or clear the '
        'current sale before adding items priced in a different currency.',
      );
    }

    if (isOfflineDemoSession) {
      return _checkoutCartOffline(
        items: items,
        customerName: customerName,
        asDebt: asDebt,
        customerPhone: customerPhone,
        debtDueDate: debtDueDate,
        debtNote: debtNote,
        currency: currency,
        manualAdjustment: manualAdjustment,
        amountPaidNow: amountPaidNow,
        existingDebtorId: existingDebtorId,
      );
    }

    return _checkoutCartOnline(
      items: items,
      customerName: customerName,
      asDebt: asDebt,
      customerPhone: customerPhone,
      debtDueDate: debtDueDate,
      debtNote: debtNote,
      currency: currency,
      manualAdjustment: manualAdjustment,
      amountPaidNow: amountPaidNow,
      existingDebtorId: existingDebtorId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<CheckoutResult> _checkoutCartOffline({
    required List<CartItem> items,
    required String customerName,
    required bool asDebt,
    required String customerPhone,
    required DateTime? debtDueDate,
    required String debtNote,
    required Currency currency,
    required double manualAdjustment,
    required double amountPaidNow,
    String? existingDebtorId,
  }) async {
    final updatedProducts = List<Product>.from(_products);
    final newSales = <SaleRecord>[];
    final productNames = <String>[];
    final now = DateTime.now();
    final transactionId = now.microsecondsSinceEpoch.toString();
    final invoiceNumber = 'INV-${transactionId.substring(0, 8).toUpperCase()}';
    var subtotal = 0.0;
    var totalProfit = 0.0;
    var productCount = 0;

    for (final item in items) {
      final index = updatedProducts.indexWhere(
        (product) => product.id == item.product.id,
      );
      if (index == -1) {
        throw CheckoutException('${item.product.name} is no longer available.');
      }
      final current = updatedProducts[index];
      if (!current.isActive || current.quantity < item.quantity) {
        throw CheckoutException(
          'Only ${current.quantity} left of ${current.name}. Please adjust your cart.',
        );
      }

      final lineTotal = current.sellingPrice * item.quantity;
      final lineProfit =
          (current.sellingPrice - current.purchasePrice) * item.quantity;
      subtotal += lineTotal;
      totalProfit += lineProfit;
      productNames.add(current.name);
      productCount += item.quantity;

      updatedProducts[index] = Product(
        id: current.id,
        name: current.name,
        normalizedName: current.normalizedName,
        serialNumber: current.serialNumber,
        barcode: current.barcode,
        categoryId: current.categoryId,
        categoryName: current.categoryName,
        purchasePrice: current.purchasePrice,
        sellingPrice: current.sellingPrice,
        quantity: current.quantity - item.quantity,
        minimumStock: current.minimumStock,
        description: current.description,
        isSerialized: current.isSerialized,
        isActive: current.isActive,
        createdAt: current.createdAt,
        updatedAt: now,
        createdBy: current.createdBy,
        currency: current.currency,
      );

      newSales.add(
        SaleRecord(
          id: '$transactionId-${newSales.length}',
          productName: current.name,
          serialNumber: current.serialNumber,
          categoryName: current.categoryName,
          quantity: item.quantity,
          unitPrice: current.sellingPrice,
          totalAmount: lineTotal,
          discount: 0,
          profit: lineProfit,
          soldAt: now,
          createdBy: currentActor,
          transactionId: transactionId,
          productId: current.id,
          currency: currency,
        ),
      );
    }

    final rawFinalTotal = subtotal + manualAdjustment;
    final finalTotal = rawFinalTotal < 0 ? 0.0 : rawFinalTotal;
    final clampedPaidNow = amountPaidNow < 0
        ? 0.0
        : (amountPaidNow > finalTotal ? finalTotal : amountPaidNow);

    final transaction = TransactionRecord(
      id: transactionId,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      paymentMethod: asDebt ? 'Debt' : 'Cash',
      productCount: productCount,
      totalAmount: finalTotal,
      profit: totalProfit,
      createdBy: currentActor,
      createdAt: now,
      productNames: productNames,
      currency: currency,
      subtotal: subtotal,
      manualAdjustment: manualAdjustment,
    );

    _products = updatedProducts;
    _sales = [...newSales, ..._sales];
    _transactions = [transaction, ..._transactions];
    notifyListeners();

    if (asDebt) {
      await addManualDebt(
        customerName: customerName,
        customerPhone: customerPhone,
        amount: finalTotal,
        currency: currency,
        note: debtNote,
        dueDate: debtDueDate,
        amountPaidNow: clampedPaidNow,
        existingDebtorId: existingDebtorId,
      );
    }

    return CheckoutResult(
      invoiceNumber: invoiceNumber,
      totalAmount: finalTotal,
      currency: currency,
    );
  }

  Future<CheckoutResult> _checkoutCartOnline({
    required List<CartItem> items,
    required String customerName,
    required bool asDebt,
    required String customerPhone,
    required DateTime? debtDueDate,
    required String debtNote,
    required Currency currency,
    required double manualAdjustment,
    required double amountPaidNow,
    String? idempotencyKey,
    String? existingDebtorId,
  }) async {
    final productsRef = _firestore.collection('products');
    final productCatalogRef = _firestore.collection('product_catalog');
    final salesRef = _firestore.collection('sales');
    final salesPublicRef = _firestore.collection('sales_public');
    final transactionsRef = _firestore.collection('transactions');
    final transactionsPublicRef = _firestore.collection('transactions_public');

    final transactionRef = idempotencyKey != null && idempotencyKey.isNotEmpty
        ? transactionsRef.doc(idempotencyKey)
        : transactionsRef.doc();
    final transactionId = transactionRef.id;
    final invoiceNumber = 'INV-${transactionId.substring(0, 8).toUpperCase()}';
    final saleRefs = [for (final _ in items) salesRef.doc()];
    final normalizedPhone = normalizeLebanesePhone(customerPhone);

    var totalAmount = 0.0;

    await _firestore.runTransaction((txn) async {
      // Idempotency guard: if this exact checkout attempt already went
      // through (e.g. a retried double-submit after a slow connection),
      // don't create a second invoice for the same cart.
      // Staff can create private transactions but cannot read them. Check the
      // signed-in-readable mirror so the idempotency guard works for both roles.
      final existingTransaction = await txn.get(
        transactionsPublicRef.doc(transactionId),
      );
      if (existingTransaction.exists) {
        throw const CheckoutException('This sale was already recorded.');
      }

      // Firestore transactions require every read before any write, so
      // fetch the current state of every product, and (for a debt sale)
      // resolve/read the matching debtor, before any write below.
      final freshProducts = <String, Product>{};
      for (final item in items) {
        final snapshot = await txn.get(productsRef.doc(item.product.id));
        if (!snapshot.exists) {
          throw CheckoutException('${item.product.name} is no longer available.');
        }
        freshProducts[item.product.id] = Product.fromMap(
          snapshot.data()!,
          snapshot.id,
        );
      }

      for (final item in items) {
        final fresh = freshProducts[item.product.id]!;
        if (!fresh.isActive || fresh.quantity < item.quantity) {
          throw CheckoutException(
            'Only ${fresh.quantity} left of ${fresh.name}. Please adjust your cart.',
          );
        }
        if (fresh.isSerialized && fresh.quantity <= 1 && item.quantity != 1) {
          throw CheckoutException('${fresh.name} can only be sold one at a time.');
        }
      }

      DocumentReference<Map<String, dynamic>>? debtorRef;
      Debtor? existingDebtor;
      if (asDebt) {
        debtorRef = await _resolveDebtorRef(
          transaction: txn,
          normalizedPhone: normalizedPhone,
          existingDebtorId: existingDebtorId,
        );
        final debtorSnapshot = await txn.get(debtorRef);
        if (debtorSnapshot.exists) {
          existingDebtor = Debtor.fromMap(debtorSnapshot.data()!, debtorRef.id);
        }
      }

      var runningSubtotal = 0.0;
      var runningProfit = 0.0;
      var productCount = 0;
      final productNames = <String>[];
      final debtorProducts = <DebtorTransactionProduct>[];

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final fresh = freshProducts[item.product.id]!;
        final lineTotal = fresh.sellingPrice * item.quantity;
        final lineProfit =
            (fresh.sellingPrice - fresh.purchasePrice) * item.quantity;
        runningSubtotal += lineTotal;
        runningProfit += lineProfit;
        productNames.add(fresh.name);
        productCount += item.quantity;
        debtorProducts.add(
          DebtorTransactionProduct(
            productId: fresh.id,
            name: fresh.name,
            quantity: item.quantity,
            unitPrice: fresh.sellingPrice,
            lineTotal: lineTotal,
          ),
        );

        final sale = SaleRecord(
          id: saleRefs[i].id,
          productName: fresh.name,
          serialNumber: fresh.serialNumber,
          categoryName: fresh.categoryName,
          quantity: item.quantity,
          unitPrice: fresh.sellingPrice,
          totalAmount: lineTotal,
          discount: 0,
          profit: lineProfit,
          soldAt: DateTime.now(),
          createdBy: currentActor,
          transactionId: transactionId,
          productId: fresh.id,
          currency: currency,
        );
        final salePayload = sale.toMap()
          ..['soldAt'] = FieldValue.serverTimestamp();
        final salePublicPayload = sale.toPublicMap()
          ..['soldAt'] = FieldValue.serverTimestamp();
        txn.set(saleRefs[i], salePayload);
        txn.set(salesPublicRef.doc(saleRefs[i].id), salePublicPayload);

        final newQuantity = fresh.quantity - item.quantity;
        final stockUpdate = {
          'quantity': newQuantity,
          'stock': newQuantity,
          'isSold': newQuantity <= 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        txn.update(productsRef.doc(fresh.id), stockUpdate);
        txn.set(
          productCatalogRef.doc(fresh.id),
          stockUpdate,
          SetOptions(merge: true),
        );
      }

      final rawFinalTotal = runningSubtotal + manualAdjustment;
      final finalTotal = rawFinalTotal < 0 ? 0.0 : rawFinalTotal;
      final clampedPaidNow = amountPaidNow < 0
          ? 0.0
          : (amountPaidNow > finalTotal ? finalTotal : amountPaidNow);

      final record = TransactionRecord(
        id: transactionId,
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        paymentMethod: asDebt ? 'Debt' : 'Cash',
        productCount: productCount,
        totalAmount: finalTotal,
        profit: runningProfit,
        createdBy: currentActor,
        createdAt: DateTime.now(),
        productNames: productNames,
        currency: currency,
        subtotal: runningSubtotal,
        manualAdjustment: manualAdjustment,
      );
      final txPayload = record.toMap()
        ..['createdAt'] = FieldValue.serverTimestamp();
      final txPublicPayload = record.toPublicMap()
        ..['createdAt'] = FieldValue.serverTimestamp();
      txn.set(transactionRef, txPayload);
      txn.set(transactionsPublicRef.doc(transactionId), txPublicPayload);

      if (asDebt && debtorRef != null) {
        final now = DateTime.now();
        final profitCents = currency.toMinorUnits(runningProfit);
        final finalTotalMinor = currency.toMinorUnits(finalTotal);
        final paidNowMinor = currency.toMinorUnits(clampedPaidNow);
        final profitRealizedNowCents = finalTotalMinor <= 0
            ? 0
            : (profitCents * paidNowMinor / finalTotalMinor)
                  .round()
                  .clamp(0, profitCents);
        final remainingMinor = finalTotalMinor - paidNowMinor;

        final debtor = Debtor(
          id: debtorRef.id,
          name: customerName,
          phoneNumber: customerPhone,
          normalizedPhone: normalizedPhone,
          note: debtNote,
          createdAt: existingDebtor?.createdAt ?? now,
          theyOweMe: true,
          usdTotalDebtCents: currency == Currency.usd
              ? (existingDebtor?.usdTotalDebtCents ?? 0) + finalTotalMinor
              : (existingDebtor?.usdTotalDebtCents ?? 0),
          usdTotalPaidCents: currency == Currency.usd
              ? (existingDebtor?.usdTotalPaidCents ?? 0) + paidNowMinor
              : (existingDebtor?.usdTotalPaidCents ?? 0),
          lbpTotalDebt: currency == Currency.lbp
              ? (existingDebtor?.lbpTotalDebt ?? 0) + finalTotalMinor
              : (existingDebtor?.lbpTotalDebt ?? 0),
          lbpTotalPaid: currency == Currency.lbp
              ? (existingDebtor?.lbpTotalPaid ?? 0) + paidNowMinor
              : (existingDebtor?.lbpTotalPaid ?? 0),
          dueDate: debtDueDate ?? existingDebtor?.dueDate,
          invoiceCount: (existingDebtor?.invoiceCount ?? 0) + 1,
          updatedAt: now,
          lastPaymentAt: paidNowMinor > 0 ? now : existingDebtor?.lastPaymentAt,
          createdBy: existingDebtor?.createdBy.isNotEmpty == true
              ? existingDebtor!.createdBy
              : currentActor,
        );
        txn.set(debtorRef, debtor.toMap(), SetOptions(merge: true));

        if (normalizedPhone.isNotEmpty) {
          txn.set(_debtorService.phoneIndexRef.doc(normalizedPhone), {
            'debtorId': debtorRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final historyRef = _debtorService.transactionsRef(debtorRef.id).doc();
        txn.set(
          historyRef,
          DebtorTransaction(
            id: historyRef.id,
            type: 'debt',
            currency: currency,
            createdBy: currentActor,
            createdAt: now,
            products: debtorProducts,
            subtotal: runningSubtotal,
            manualAdjustment: manualAdjustment,
            finalTotal: finalTotal,
            paidAmount: clampedPaidNow,
            remainingBalanceAfter: currency.fromMinorUnits(remainingMinor),
            note: debtNote,
            linkedTransactionId: transactionId,
            profitCents: profitCents,
            profitRealizedCents: profitRealizedNowCents,
          ).toMap(),
        );

        if (clampedPaidNow > 0) {
          final paymentRef = _firestore.collection('payments').doc();
          txn.set(
            paymentRef,
            PaymentRecord(
              id: paymentRef.id,
              debtorId: debtorRef.id,
              customerName: customerName,
              amount: clampedPaidNow,
              note: 'Paid at time of sale',
              receivedBy: currentActor,
              paidAt: now,
              invoiceId: transactionId,
              currency: currency,
              profit: currency.fromMinorUnits(profitRealizedNowCents),
              remainingAfter: currency.fromMinorUnits(remainingMinor),
            ).toMap(),
          );
        }
      }

      totalAmount = finalTotal;
    });

    return CheckoutResult(
      invoiceNumber: invoiceNumber,
      totalAmount: totalAmount,
      currency: currency,
    );
  }

  /// Permanently deletes a transaction/invoice: removes every sale line
  /// item it created and restores the stock quantity each one decremented.
  Future<void> deleteTransaction(TransactionRecord transaction) async {
    if (isOfflineDemoSession) {
      _deleteTransactionOffline(transaction);
      return;
    }
    await _deleteTransactionOnline(transaction);
  }

  void _deleteTransactionOffline(TransactionRecord transaction) {
    final linkedSales = _sales
        .where((sale) => sale.transactionId == transaction.id)
        .toList();

    var updatedProducts = List<Product>.from(_products);
    for (final sale in linkedSales) {
      final index = updatedProducts.indexWhere(
        (product) => product.id == sale.productId,
      );
      if (index == -1) {
        continue;
      }
      final current = updatedProducts[index];
      updatedProducts[index] = Product(
        id: current.id,
        name: current.name,
        normalizedName: current.normalizedName,
        serialNumber: current.serialNumber,
        barcode: current.barcode,
        categoryId: current.categoryId,
        categoryName: current.categoryName,
        purchasePrice: current.purchasePrice,
        sellingPrice: current.sellingPrice,
        quantity: current.quantity + sale.quantity,
        minimumStock: current.minimumStock,
        description: current.description,
        isSerialized: current.isSerialized,
        isActive: current.isActive,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
        createdBy: current.createdBy,
      );
    }

    final linkedSaleIds = linkedSales.map((sale) => sale.id).toSet();
    _products = updatedProducts;
    _sales = _sales.where((sale) => !linkedSaleIds.contains(sale.id)).toList();
    _transactions = _transactions
        .where((item) => item.id != transaction.id)
        .toList();
    notifyListeners();
  }

  Future<void> _deleteTransactionOnline(TransactionRecord transaction) async {
    final productsRef = _firestore.collection('products');
    final productCatalogRef = _firestore.collection('product_catalog');
    final salesRef = _firestore.collection('sales');
    final salesPublicRef = _firestore.collection('sales_public');
    final transactionsRef = _firestore.collection('transactions');
    final transactionsPublicRef = _firestore.collection('transactions_public');

    // Firestore transactions can't run queries, so find the linked sale
    // docs first, then delete everything (and restore stock) atomically.
    final linkedSales = await salesRef
        .where('transactionId', isEqualTo: transaction.id)
        .get();

    final restoreByProduct = <String, int>{};
    for (final doc in linkedSales.docs) {
      final productId = doc.data()['productId'] as String? ?? '';
      final quantity = doc.data()['quantity'] as int? ?? 0;
      if (productId.isEmpty) {
        continue;
      }
      restoreByProduct[productId] = (restoreByProduct[productId] ?? 0) + quantity;
    }

    await _firestore.runTransaction((txn) async {
      final freshProducts = <String, Product>{};
      for (final productId in restoreByProduct.keys) {
        final snapshot = await txn.get(productsRef.doc(productId));
        if (snapshot.exists) {
          freshProducts[productId] = Product.fromMap(
            snapshot.data() ?? <String, dynamic>{},
            snapshot.id,
          );
        }
      }

      for (final entry in restoreByProduct.entries) {
        final fresh = freshProducts[entry.key];
        if (fresh == null) {
          continue;
        }
        final restoredQuantity = fresh.quantity + entry.value;
        final stockUpdate = {
          'quantity': restoredQuantity,
          'stock': restoredQuantity,
          'isSold': restoredQuantity <= 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        txn.update(productsRef.doc(entry.key), stockUpdate);
        txn.set(
          productCatalogRef.doc(entry.key),
          stockUpdate,
          SetOptions(merge: true),
        );
      }

      for (final doc in linkedSales.docs) {
        txn.delete(salesRef.doc(doc.id));
        txn.delete(salesPublicRef.doc(doc.id));
      }

      txn.delete(transactionsRef.doc(transaction.id));
      txn.delete(transactionsPublicRef.doc(transaction.id));
    });
  }

  List<Product> searchProducts({String query = '', String? categoryId}) {
    final normalized = query.trim().toLowerCase();
    return _products.where((product) {
      final matchesQuery =
          normalized.isEmpty ||
          product.name.toLowerCase().contains(normalized) ||
          product.normalizedName.contains(normalized) ||
          product.serialNumber.toLowerCase().contains(normalized) ||
          product.barcode.toLowerCase().contains(normalized) ||
          product.categoryName.toLowerCase().contains(normalized);
      final matchesCategory =
          categoryId == null ||
          categoryId.isEmpty ||
          product.categoryId == categoryId;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Map<String, double> topSellingProducts() {
    final totals = <String, double>{};
    for (final sale in _reportableSales) {
      totals[sale.productName] =
          (totals[sale.productName] ?? 0) + sale.totalAmount;
    }
    return Map.fromEntries(
      totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Profit per product, keyed the same way as [topSellingProducts] so the
  /// Reports screen can show the matching profit figure alongside each bar.
  Map<String, double> productProfit() {
    final totals = <String, double>{};
    for (final sale in _reportableSales) {
      totals[sale.productName] = (totals[sale.productName] ?? 0) + sale.profit;
    }
    return totals;
  }

  Map<String, double> categorySales() {
    final totals = <String, double>{};
    for (final sale in _reportableSales) {
      totals[sale.categoryName] =
          (totals[sale.categoryName] ?? 0) + sale.totalAmount;
    }
    return Map.fromEntries(
      totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Profit per category, keyed the same way as [categorySales] so the
  /// Reports screen can show "Best categories" ranked by sales with the
  /// matching profit figure alongside each bar.
  Map<String, double> categoryProfit() {
    final totals = <String, double>{};
    for (final sale in _reportableSales) {
      totals[sale.categoryName] = (totals[sale.categoryName] ?? 0) + sale.profit;
    }
    return totals;
  }

  /// The highest-value sales within [categoryName], newest-highest first —
  /// backs the "tap a category to see its top transactions" drill-down on
  /// the Reports screen.
  List<SaleRecord> topSalesForCategory(String categoryName, {int limit = 10}) {
    final matches = _reportableSales
        .where((sale) => sale.categoryName == categoryName)
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return matches.take(limit).toList();
  }

  /// Total profit for each of the last [months] calendar months (oldest
  /// first), keyed by the first-of-month date. Shared by [monthlyProfitSeries]
  /// and [monthlyProfitByYear]. Only counts sales linked to a transaction
  /// that still exists. Cash-sale profit is bucketed by sale date; debt-sale
  /// profit is bucketed by payment date, since it isn't realized until the
  /// debtor pays.
  Map<DateTime, double> _monthlyProfitBuckets({required int months}) {
    final now = DateTime.now();
    final buckets = <DateTime, double>{
      for (var i = months - 1; i >= 0; i--)
        DateTime(now.year, now.month - i, 1): 0,
    };

    final txById = _transactionsById;
    for (final sale in _reportableSales) {
      final transaction = txById[sale.transactionId];
      if (transaction != null && transaction.paymentMethod == 'Debt') {
        continue;
      }
      final key = DateTime(sale.soldAt.year, sale.soldAt.month, 1);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + sale.profit;
      }
    }
    for (final payment in _payments) {
      if (payment.currency != Currency.usd) {
        continue;
      }
      final key = DateTime(payment.paidAt.year, payment.paidAt.month, 1);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + payment.profit;
      }
    }
    for (final job in _maintenanceJobs) {
      if (job.currency != Currency.usd) {
        continue;
      }
      final key = DateTime(job.date.year, job.date.month, 1);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + job.profit;
      }
    }
    for (final bill in _bills) {
      final key = DateTime(bill.paidAt.year, bill.paidAt.month, 1);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! - bill.amount;
      }
    }
    return buckets;
  }

  /// Total profit per month for the last [months] months (oldest first),
  /// keyed by a short month-name label (e.g. "Aug"). The year is
  /// intentionally omitted: within a short window no month name ever
  /// repeats even across a year boundary, and including it (e.g. "26" for
  /// 2026) reads as a confusing stray number. Used by the report exports;
  /// the Reports screen chart itself uses [monthlyProfitByYear] instead so
  /// it can label each year explicitly.
  Map<String, double> monthlyProfitSeries({int months = 6}) {
    final formatter = DateFormat('MMM');
    return {
      for (final entry in _monthlyProfitBuckets(months: months).entries)
        formatter.format(entry.key): entry.value,
    };
  }

  /// Same monthly profit data as [monthlyProfitSeries], but split into
  /// consecutive year groups (oldest first) so the Reports chart can show a
  /// year label once per group instead of repeating it on every bar.
  List<({int year, Map<String, double> months})> monthlyProfitByYear({
    int months = 12,
  }) {
    final formatter = DateFormat('MMM');
    final orderedYears = <int>[];
    final byYear = <int, Map<String, double>>{};

    for (final entry in _monthlyProfitBuckets(months: months).entries) {
      final year = entry.key.year;
      final monthsForYear = byYear.putIfAbsent(year, () {
        orderedYears.add(year);
        return <String, double>{};
      });
      monthsForYear[formatter.format(entry.key)] = entry.value;
    }

    return [
      for (final year in orderedYears) (year: year, months: byYear[year]!),
    ];
  }

  /// Midnight [days] calendar days ago (inclusive of today), e.g. days: 1 is
  /// midnight today and days: 7 spans today plus the previous 6 days.
  DateTime _rangeStart({required int days}) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
  }

  List<SaleRecord> _salesInRange({required int days}) {
    final since = _rangeStart(days: days);
    return _reportableSales
        .where((sale) => !sale.soldAt.isBefore(since))
        .toList();
  }

  List<PaymentRecord> _paymentsInRange({required int days}) {
    final since = _rangeStart(days: days);
    return _payments
        .where((payment) => !payment.paidAt.isBefore(since))
        .toList();
  }

  List<Bill> _billsInRange({required int days}) {
    final since = _rangeStart(days: days);
    return _bills.where((bill) => !bill.paidAt.isBefore(since)).toList();
  }

  List<MaintenanceJob> _maintenanceJobsInRange({required int days}) {
    final since = _rangeStart(days: days);
    return _maintenanceJobs.where((job) => !job.date.isBefore(since)).toList();
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
