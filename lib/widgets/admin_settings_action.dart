import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../theme/app_theme.dart';

class AdminSettingsAction extends StatelessWidget {
  const AdminSettingsAction({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Admin settings',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => showDialog<void>(context: context, builder: (_) => const _AdminSettingsDialog()),
  );
}

class _AdminSettingsDialog extends StatelessWidget {
  const _AdminSettingsDialog();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Settings'),
    content: SizedBox(
      width: 380,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700))),
        ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (context, _) => SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
            ],
            selected: {ThemeController.instance.mode},
            onSelectionChanged: (value) => ThemeController.instance.setMode(value.first),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 4), leading: const Icon(Icons.lock_outline), title: const Text('Change password'), onTap: () {
          Navigator.pop(context);
          showDialog<void>(context: context, builder: (_) => const _ChangeAdminPasswordDialog());
        }),
        ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 4), leading: const Icon(Icons.quiz_outlined), title: const Text('Recovery question'), onTap: () {
          Navigator.pop(context);
          showDialog<void>(context: context, builder: (_) => const _SecurityQuestionsDialog());
        }),
      ]),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  );
}

class _ChangeAdminPasswordDialog extends StatefulWidget {
  const _ChangeAdminPasswordDialog();
  @override
  State<_ChangeAdminPasswordDialog> createState() => _ChangeAdminPasswordDialogState();
}
class _ChangeAdminPasswordDialogState extends State<_ChangeAdminPasswordDialog> {
  final _current = TextEditingController(), _next = TextEditingController(), _confirm = TextEditingController();
  bool _obscure = true, _saving = false;
  String? _error;
  @override
  void dispose() { _current.dispose(); _next.dispose(); _confirm.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_next.text.length < 8) { setState(() => _error = 'New password must contain at least 8 characters.'); return; }
    if (_next.text != _confirm.text) { setState(() => _error = 'New passwords do not match.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await AdminAuthService.instance.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
    } catch (e) { if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change password'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _current, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Current password')),
      const SizedBox(height: 12),
      TextField(controller: _next, obscureText: _obscure, decoration: const InputDecoration(labelText: 'New password')),
      const SizedBox(height: 12),
      TextField(controller: _confirm, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Confirm new password')),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), label: Text(_obscure ? 'Show passwords' : 'Hide passwords'))),
      if (_error != null) Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Update password'))],
  );
}

class _SecurityQuestionsDialog extends StatefulWidget {
  const _SecurityQuestionsDialog();
  @override
  State<_SecurityQuestionsDialog> createState() => _SecurityQuestionsDialogState();
}
class _SecurityQuestionsDialogState extends State<_SecurityQuestionsDialog> {
  final _current = TextEditingController();
  final _answer = TextEditingController();
  String? _selected;
  bool _saving = false;
  String? _error;
  @override
  void dispose() { _current.dispose(); _answer.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_selected == null) { setState(() => _error = 'Select a security question.'); return; }
    if (_answer.text.trim().length < 3) { setState(() => _error = 'Answer must contain at least 3 characters.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await AdminAuthService.instance.saveRecoveryAnswers(_current.text, {_selected!: _answer.text});
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery question saved.')));
    } catch (e) { if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Recovery question'),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: _selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Security question'),
        items: AdminAuthService.securityQuestions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _selected = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: _answer, obscureText: true, decoration: const InputDecoration(labelText: 'Answer')),
      const SizedBox(height: 12),
      TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
      if (_error != null) Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save question'))],
  );
}
