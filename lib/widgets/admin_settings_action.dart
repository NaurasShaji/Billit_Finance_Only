import '../screens/backup_screen.dart';
import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../theme/app_theme.dart';

class AdminSettingsAction extends StatelessWidget {
  const AdminSettingsAction({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Admin settings',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _AdminSettingsPage(onLogout: onLogout))),
  );
}
class _AdminSettingsPage extends StatelessWidget {
  const _AdminSettingsPage({required this.onLogout});
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ListenableBuilder(listenable: ThemeController.instance, builder: (context, _) => SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Auto')),
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
        ],
        selected: {ThemeController.instance.mode},
        onSelectionChanged: (value) => ThemeController.instance.setMode(value.first),
      )),
      const SizedBox(height: 20),
      const Text('Cloud backup', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Card(child: ListTile(
        leading: const Icon(Icons.cloud_sync_outlined),
        title: const Text('Google Drive backup'),
        subtitle: const Text('Connect Drive, create backups and restore shop data'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BackupScreen(onLogout: () {}, showLogout: false),
        )),
      )),
      const SizedBox(height: 20),
      Card(child: ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Change password'), subtitle: const Text('Update the administrator password'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ChangePasswordPage())))),
      Card(child: ListTile(leading: const Icon(Icons.quiz_outlined), title: const Text('Recovery question'), subtitle: const Text('Update the password recovery answer'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _RecoveryQuestionPage())))),
      const SizedBox(height: 20),
      const Text('Session', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          title: Text('Log out', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          subtitle: const Text('End this session and require your password next time'),
          onTap: () async {
            final shouldLogout = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Log out of Billit Finance?'),
                content: const Text('You will need to enter your admin password the next time you open the app.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            );
            if (shouldLogout == true && context.mounted) {
              Navigator.of(context).pop();
              onLogout();
            }
          },
        ),
      ),
    ]))),
  );
}
class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();
  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}
class _ChangePasswordPageState extends State<_ChangePasswordPage> {
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change password')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: ListView(padding: const EdgeInsets.all(20), children: [
      TextField(controller: _current, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Current password')),
      const SizedBox(height: 12),
      TextField(controller: _next, obscureText: _obscure, decoration: const InputDecoration(labelText: 'New password')),
      const SizedBox(height: 12),
      TextField(controller: _confirm, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Confirm new password')),
      TextButton.icon(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), label: Text(_obscure ? 'Show passwords' : 'Hide passwords')),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 16),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Update password')),
    ]))),
  );
}
class _RecoveryQuestionPage extends StatefulWidget {
  const _RecoveryQuestionPage();
  @override
  State<_RecoveryQuestionPage> createState() => _RecoveryQuestionPageState();
}
class _RecoveryQuestionPageState extends State<_RecoveryQuestionPage> {
  final _current = TextEditingController(), _answer = TextEditingController();
  String? _selected, _error;
  bool _saving = false;
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recovery question')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: ListView(padding: const EdgeInsets.all(20), children: [
      DropdownButtonFormField<String>(value: _selected, isExpanded: true, decoration: const InputDecoration(labelText: 'Security question'),
        items: AdminAuthService.securityQuestions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _selected = v)),
      const SizedBox(height: 12),
      TextField(controller: _answer, obscureText: true, decoration: const InputDecoration(labelText: 'Answer')),
      const SizedBox(height: 12),
      TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 16),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save question')),
    ]))),
  );
}
