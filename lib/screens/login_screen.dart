import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated});
  final VoidCallback onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _configured = false;
  bool _loading = true;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configured = await AdminAuthService.instance.isConfigured;
    if (!mounted) return;
    setState(() { _configured = configured; _loading = false; });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final password = _password.text;
    if (!_configured) {
      if (password.length < 8) {
        setState(() => _error = 'Use at least 8 characters.');
        return;
      }
      if (password != _confirm.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
      await AdminAuthService.instance.configure(password);
      widget.onAuthenticated();
      return;
    }
    if (await AdminAuthService.instance.verify(password)) {
      widget.onAuthenticated();
    } else {
      setState(() => _error = 'Incorrect admin password.');
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/icon/billit_logo.svg', height: 56, errorBuilder: (_, __, ___) =>
                      Image.asset('assets/icon/billit_icon.png', height: 64)),
                    const SizedBox(height: 24),
                    Text(_configured ? 'Admin Login' : 'Set Up Admin Account',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('This standalone finance app has one administrator account.',
                      textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: _configured ? 'Admin password' : 'Create admin password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (!_configured) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: const InputDecoration(labelText: 'Confirm password'),
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(_configured ? 'Sign in' : 'Create admin account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
