import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});
  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordPageState();
}
class _ForgotPasswordPageState extends State<ForgotPasswordDialog> {
  List<String> _questionIds = [];
  final _answers = <String, TextEditingController>{};
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = true, _saving = false, _obscure = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final ids = await AdminAuthService.instance.getRecoveryQuestionIds();
    if (!mounted) return;
    setState(() {
      _questionIds = ids;
      for (final id in ids) { _answers[id] = TextEditingController(); }
      _loading = false;
    });
  }
  @override
  void dispose() {
    for (final c in _answers.values) { c.dispose(); }
    _password.dispose(); _confirm.dispose(); super.dispose();
  }
  Future<void> _reset() async {
    if (_password.text.length < 8) { setState(() => _error = 'New password must contain at least 8 characters.'); return; }
    if (_password.text != _confirm.text) { setState(() => _error = 'Passwords do not match.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await AdminAuthService.instance.resetPasswordWithRecovery(
        {for (final id in _questionIds) id: _answers[id]!.text}, _password.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: ListView(padding: const EdgeInsets.all(20), children: [
      if (_loading) const LinearProgressIndicator()
      else if (_questionIds.isEmpty) const Text('Password recovery is not set up.')
      else ...[
        for (final id in _questionIds) ...[
          Text(AdminAuthService.securityQuestions[id] ?? 'Security question', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(controller: _answers[id], decoration: const InputDecoration(labelText: 'Your answer')),
          const SizedBox(height: 12),
        ],
        TextField(controller: _password, obscureText: _obscure, decoration: const InputDecoration(labelText: 'New password')),
        const SizedBox(height: 10),
        TextField(controller: _confirm, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Confirm new password')),
        TextButton.icon(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), label: Text(_obscure ? 'Show passwords' : 'Hide passwords')),
      ],
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel'))),
        const SizedBox(width: 12),
        if (!_loading && _questionIds.isNotEmpty) Expanded(child: FilledButton(onPressed: _saving ? null : _reset, child: Text(_saving ? 'Verifying…' : 'Reset password'))),
      ]),
    ]))),
  );
}
