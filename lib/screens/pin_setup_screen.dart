import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/pin_pad.dart';

/// Asks for a new 4-digit PIN twice. Returns true when the PIN was saved.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  static Future<bool?> open(BuildContext context) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
  }

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  String? _error;

  Future<void> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'The two PINs did not match. Start again.';
      });
      return;
    }
    await context.read<SecurityProvider>().setPin(pin);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return SubScreen(
      title: 'Set a PIN',
      subtitle: 'Keeps your ledger private on this phone',
      child: Center(
        child: PinPad(
          title: confirming ? 'Enter it again' : 'Choose a 4-digit PIN',
          subtitle: confirming
              ? 'Type the same PIN to confirm'
              : 'You will need it to open the app',
          error: _error,
          onComplete: _onPin,
        ),
      ),
    );
  }
}
