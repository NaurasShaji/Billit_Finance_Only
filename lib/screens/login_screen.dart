import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/admin_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated});
  final VoidCallback onAuthenticated;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool configured = false;
  bool loading = true;
  bool obscure = true;
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final value = await AdminAuthService.instance.isConfigured; if (mounted) setState(() { configured = value; loading = false; }); }
  Future<void> _submit() async {
    setState(() => error = null);
    if (!configured) {
      if (_password.text.length < 8) { setState(() => error = 'Use at least 8 characters.'); return; }
      if (_password.text != _confirm.text) { setState(() => error = 'Passwords do not match.'); return; }
      await AdminAuthService.instance.configure(_password.text);
      widget.onAuthenticated();
      return;
    }
    if (await AdminAuthService.instance.verify(_password.text)) { widget.onAuthenticated(); }
    else { setState(() => error = 'Incorrect admin password.'); }
  }
  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(body: Center(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Card(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SvgPicture.asset('assets/icon/billit_logo.svg', height: 58, semanticsLabel: 'Billit'),
        const SizedBox(height: 28),
        Text(configured ? 'Welcome back' : 'Set up your workspace', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 8),
        Text(configured ? 'Sign in to manage your finance operations.' : 'Create the administrator password for this device.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 24),
        TextField(controller: _password, obscureText: obscure, decoration: InputDecoration(labelText: configured ? 'Admin password' : 'Create admin password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off))), onSubmitted: (_) => _submit()),
        if (!configured) ...[const SizedBox(height: 12), TextField(controller: _confirm, obscureText: obscure, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined)), onSubmitted: (_) => _submit())],
        if (error != null) ...[const SizedBox(height: 12), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
        const SizedBox(height: 22),
        FilledButton(onPressed: _submit, child: Text(configured ? 'Sign in' : 'Create admin account')),
      ]))),
    )))));
  }
}
