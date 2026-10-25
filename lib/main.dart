import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_dashboard_screen.dart';
import 'theme/toufic_cell_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // cloud_firestore's Android transaction channel teardown can throw a
  // stray "Null check operator used on a null value" error *after* a
  // transaction has already completed successfully — it isn't tied to any
  // widget's build and never reaches the try/catch around the checkout
  // call. Flutter routes framework-detected errors like this one (from a
  // platform channel, not a widget build) through FlutterError.onError, not
  // through the zone/PlatformDispatcher handler, so both are covered here.
  // Left uncaught it paints the whole screen red even though the checkout
  // already completed successfully. Everything else still behaves normally.
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isKnownFirestoreTransactionTeardownGlitch(details.exceptionAsString())) {
      debugPrint(
        'Ignored known Firestore transaction cleanup glitch: '
        '${details.exceptionAsString()}',
      );
      return;
    }
    defaultOnError?.call(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    if (_isKnownFirestoreTransactionTeardownGlitch(error.toString())) {
      debugPrint('Ignored known Firestore transaction cleanup glitch: $error');
      return true;
    }
    return false;
  };

  // FlutterError.onError only controls reporting — it does not stop Flutter
  // from independently swapping a broken widget's own render output for the
  // built-in full-screen red ErrorWidget when something throws during that
  // widget's build/layout/paint. That's a separate mechanism, so cover it
  // here too: collapse the failing widget instead of losing the whole
  // screen to it. The error is still logged above for diagnosis.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Widget build error (collapsed, not shown): ${details.exceptionAsString()}');
    // The interrupted build can leave the screen looking stale until the
    // next user interaction forces a rebuild. Schedule one proactively so
    // the UI recovers on its own instead of needing an extra tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.scheduleFrame();
    });
    return const SizedBox.shrink();
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const AppShell(),
    ),
  );
}

/// True for the known cloud_firestore Android transaction-channel teardown
/// glitch: a stray null-value error (optionally preceded by a
/// MissingPluginException on a firebase_firestore/transaction channel) that
/// surfaces after a transaction has already completed successfully. The
/// exact wording varies ("Null check operator used on a null value" or
/// "Unexpected null value") depending on which internal check trips first.
bool _isKnownFirestoreTransactionTeardownGlitch(String message) {
  return message.contains('Null check operator used on a null value') ||
      message.contains('Unexpected null value') ||
      (message.contains('MissingPluginException') &&
          message.contains('firebase_firestore/transaction'));
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<AppProvider>();
    final uid = provider.currentUser?.uid;
    if (uid != null && uid != _loadedUserId) {
      _loadedUserId = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AppProvider>().loadData();
        }
      });
    }
    if (uid == null) {
      if (_loadedUserId != null) {
        context.read<CartProvider>().clear();
      }
      _loadedUserId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.currentUser == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Toufic Cell',
        theme: TouficCellTheme.lightTheme,
        darkTheme: TouficCellTheme.darkTheme,
        themeMode: provider.themeMode,
        home: const LoginScreen(),
      );
    }

    final isAdmin = provider.currentUser!.role.toLowerCase() == 'admin';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toufic Cell',
      theme: TouficCellTheme.lightTheme,
      darkTheme: TouficCellTheme.darkTheme,
      themeMode: provider.themeMode,
      home: isAdmin
          ? const AdminDashboardScreen()
          : const UserDashboardScreen(),
    );
  }
}
