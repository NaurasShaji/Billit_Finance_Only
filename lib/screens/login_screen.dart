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
  final _newPassword = TextEditingController();
  bool configured = false;
  bool mustChange = false;
  bool initialChange = false;
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
    final forceChange = await AdminAuthService.instance.mustChangePassword;
    if (mounted) {
      setState(() {
        configured = value;
        mustChange = forceChange;
        loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (busy) return;
    setState(() => error = null);

    if (initialChange) {
      if (_newPassword.text.length < 8) {
        setState(() => error = 'Use at least 8 characters for the new password.');
        return;
      }
      if (_newPassword.text != _confirm.text) {
        setState(() => error = 'New passwords do not match.');
        return;
      }
      setState(() => busy = true);
      try {
        await AdminAuthService.instance.changePassword(
          _password.text,
          _newPassword.text,
        );
        if (mounted) widget.onAuthenticated();
      } catch (e) {
        if (mounted) {
          setState(() {
            busy = false;
            error = e.toString().replaceFirst('Exception: ', '');
          });
        }
      }
      return;
    }

    setState(() => busy = true);
    final ok = await AdminAuthService.instance.verify(_password.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        busy = false;
        error = 'Incorrect password.';
      });
      return;
    }
    if (mustChange) {
      setState(() {
        busy = false;
        initialChange = true;
        _newPassword.clear();
        _confirm.clear();
      });
      return;
    }
    widget.onAuthenticated();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _newPassword.dispose();
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
                      initialChange ? 'Change your default password' : (configured ? 'Welcome back' : 'Create admin password'),
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
                      textInputAction: initialChange || configured
                          ? TextInputAction.done
                          : TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: initialChange ? 'Current temporary password' : 'Password',
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
                    if (initialChange) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPassword,
                        obscureText: obscure,
                        decoration: const InputDecoration(
                          labelText: 'New password (8+ characters)',
                          prefixIcon: Icon(Icons.password_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        obscureText: obscure,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ] else if (!configured) ...[
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
                    if (configured) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            final reset = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordDialog()),
                            );
                            if (reset == true && mounted) {
                              _password.clear();
                              setState(() => error = null);
                            }
                          },
                          child: const Text('Forgot password?'),
                        ),
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
                          : Text(initialChange ? 'Save new password' : (configured ? 'Continue' : 'Create account')),
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
