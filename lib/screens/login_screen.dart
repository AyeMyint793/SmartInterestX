import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService().signIn(email: email, password: _password.text);
      if (!mounted) return;
      // AuthGate (the first screen) now shows the app. Close this screen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AuthService.message(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Welcome back',
      subtitle: 'Open your ledger',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.red),
              ),
            ),
          PrimaryButton(
            label: _busy ? 'Logging in…' : 'Log in',
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        children: [
          AppTextField(
            label: 'Email address',
            controller: _email,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            suffixIcon: Icons.mail_outline,
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Password',
            controller: _password,
            hint: 'Your password',
            obscureText: true,
            suffixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
              child: const Text(
                'New here? Create a ledger',
                style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
