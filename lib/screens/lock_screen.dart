import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/pin_pad.dart';

/// Wraps the whole app. Shows the lock screen on top when the app is locked,
/// and locks the app again when you come back after leaving it.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final security = context.read<SecurityProvider>();
    if (state == AppLifecycleState.paused) {
      security.appPaused();
    } else if (state == AppLifecycleState.resumed) {
      security.appResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityProvider>();
    if (!security.loaded) {
      return const ColoredBox(color: AppColors.background);
    }
    return Stack(
      children: [
        widget.child,
        if (security.locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Ask for the fingerprint straight away if it is switched on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<SecurityProvider>().biometricEnabled) {
        _useBiometric();
      }
    });
  }

  Future<void> _useBiometric() async {
    final security = context.read<SecurityProvider>();
    final ok = await security.authenticateBiometric('Unlock SmartInterestX');
    if (ok && mounted) security.unlock();
  }

  void _check(String pin) {
    final security = context.read<SecurityProvider>();
    if (security.verifyPin(pin)) {
      security.unlock();
    } else {
      setState(() => _error = 'Wrong PIN. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: PinPad(
            title: 'Enter your PIN',
            subtitle: 'SmartInterestX is locked',
            error: _error,
            onComplete: _check,
            onBiometric: security.biometricEnabled ? _useBiometric : null,
          ),
        ),
      ),
    );
  }
}
