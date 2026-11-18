import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/admin_auth_service.dart';
import '../theme/app_theme.dart';
import 'forgot_password_dialog.dart';

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
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await AdminAuthService.instance.isConfigured;
    if (mounted) {
      setState(() {
        configured = value;
        loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (busy) return;
    setState(() => error = null);
    if (!configured) {
      if (_password.text.length < 8) {
        setState(() => error = 'Use at least 8 characters.');
        return;
      }
      if (_password.text != _confirm.text) {
        setState(() => error = 'Passwords do not match.');
        return;
      }
      await AdminAuthService.instance.configure(_password.text);
      widget.onAuthenticated();
      return;
    }
    setState(() => busy = true);
    final ok = await AdminAuthService.instance.verify(_password.text);
    if (!mounted) return;
    if (ok) {
      widget.onAuthenticated();
    } else {
      setState(() {
        busy = false;
        error = 'Incorrect password.';
      });
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
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvgPicture.asset(
                      'assets/icon/billit_logo.svg',
                      height: 56,
                      semanticsLabel: 'Billit',
                    ),
                    const SizedBox(height: 28),
                    Text(
                      configured ? 'Welcome back' : 'Create admin password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.ink,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _password,
                      obscureText: obscure,
                      autofocus: true,
                      textInputAction: configured
                          ? TextInputAction.done
                          : TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => configured ? _submit() : null,
                    ),
                    if (!configured) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        obscureText: obscure,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(configured ? 'Sign in' : 'Create account'),
                    ),
                    if (configured) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () async {
                          final reset = await showDialog<bool>(
                            context: context,
                            builder: (_) => const ForgotPasswordDialog(),
                          );
                          if (reset == true && mounted) {
                            _password.clear();
                            setState(() => error = null);
                          }
                        },
                        child: const Text('Forgot password?'),
                      ),
                    ],
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
