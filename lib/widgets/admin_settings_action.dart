import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';

class AdminSettingsAction extends StatelessWidget {
  const AdminSettingsAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Admin settings',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => const _ChangeAdminPasswordDialog(),
    ),
  );
}

class _ChangeAdminPasswordDialog extends StatefulWidget {
  const _ChangeAdminPasswordDialog();

  @override
  State<_ChangeAdminPasswordDialog> createState() => _ChangeAdminPasswordDialogState();
}

class _ChangeAdminPasswordDialogState extends State<_ChangeAdminPasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.length < 8) {
      setState(() => _error = 'New password must contain at least 8 characters.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await AdminAuthService.instance.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin password changed successfully.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change admin password'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _current,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'New password', helperText: 'Use at least 8 characters'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'Confirm new password'),
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              label: Text(_obscure ? 'Show passwords' : 'Hide passwords'),
            ),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
    ),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Update password')),
    ],
  );
}
