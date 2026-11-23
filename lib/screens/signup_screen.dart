import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await AuthService().signUp(
        name: name,
        email: email,
        password: _password.text,
      );
      if (!mounted) return;
      final ledger = context.read<LedgerProvider>();
      if (user != null) {
        ledger.start(user.uid, displayName: name, email: email);
      }
      ledger.change(() => ledger.userName = name);
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
      title: 'Create your ledger',
      subtitle: 'One account keeps your records safe',
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
            label: _busy ? 'Creating account…' : 'Create account',
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        children: [
          AppTextField(
            label: 'Full name',
            controller: _name,
            hint: 'Priya Desai',
            suffixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
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
            hint: 'At least 6 characters',
            obscureText: true,
            suffixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text(
                'I already have a ledger',
                style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const HintText('A record-keeping app. No money is moved here.'),
        ],
      ),
    );
  }
}
