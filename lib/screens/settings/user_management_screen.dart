import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/admin_auth_service.dart';
import '../../widgets/role_guard.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(allowAdmin: true, child: _UserManagementView());
  }
}

class _UserManagementView extends StatelessWidget {
  const _UserManagementView();

  Future<void> _changePassword(
    BuildContext context,
    AppProvider provider,
    AppUser user,
  ) async {
    if (provider.isOfflineDemoSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password changes require a Firebase-connected admin account.',
          ),
        ),
      );
      return;
    }

    final newPassword = await showDialog<String>(
      context: context,
      builder: (_) => _ChangePasswordDialog(email: user.email),
    );
    if (newPassword == null || !context.mounted) return;

    try {
      await AdminAuthService().changeUserPassword(
        uid: user.uid,
        newPassword: newPassword,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password changed for ${user.email}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change password: $error')),
      );
    }
  }

  Future<void> _setActive(
    BuildContext context,
    AppProvider provider,
    AppUser user,
  ) async {
    final nextActive = !user.isActive;
    final action = nextActive ? 'reactivate' : 'deactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${nextActive ? 'Reactivate' : 'Deactivate'} account?'),
        content: Text(
          nextActive
              ? 'This account will be able to sign in again.'
              : 'This account will lose access to the application. Its sales '
                    'and history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(nextActive ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await provider.setUserActive(user, nextActive);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account ${action}d successfully.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not $action account: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final users = [...provider.users]
      ..sort((left, right) => left.email.compareTo(right.email));

    return Scaffold(
      appBar: AppBar(title: const Text('Application users')),
      body: users.isEmpty
          ? const Center(child: Text('No user accounts found.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Manage who can access the store app. Deactivated accounts '
                  'keep their records but cannot access store data or sign in. '
                  'Password changes apply to the selected account immediately.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                ...users.map((user) {
                  final isCurrentUser = user.uid == provider.currentUser?.uid;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          user.isAdmin
                              ? Icons.admin_panel_settings_outlined
                              : Icons.person_outline,
                        ),
                      ),
                      title: Text(user.email),
                      subtitle: Text(
                        '${user.isAdmin ? 'Admin' : 'User'} · '
                        '${user.isActive ? 'Active' : 'Deactivated'}'
                        '${isCurrentUser ? ' · You' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Change password',
                            onPressed: () =>
                                _changePassword(context, provider, user),
                            icon: const Icon(Icons.key_outlined),
                          ),
                          if (isCurrentUser)
                            const Chip(label: Text('You'))
                          else
                            TextButton(
                              onPressed: () =>
                                  _setActive(context, provider, user),
                              child: Text(
                                user.isActive ? 'Deactivate' : 'Reactivate',
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.email});

  final String email;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change account password'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Set a new password for ${widget.email}.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) {
                  final length = (value ?? '').length;
                  if (length < 6) {
                    return 'Use at least 6 characters.';
                  }
                  if (length > 128) {
                    return 'Use no more than 128 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmationController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_passwordController.text);
            }
          },
          child: const Text('Change password'),
        ),
      ],
    );
  }
}
