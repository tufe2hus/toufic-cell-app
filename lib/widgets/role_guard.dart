import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowAdmin,
    required this.child,
    this.message = 'You do not have permission to access this page.',
  });

  final bool allowAdmin;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allowed = allowAdmin ? provider.isAdmin : !provider.isAdmin;
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(message)),
      );
    }
    return child;
  }
}
