import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Four dots plus a number keypad. Calls [onComplete] after the 4th digit,
/// then clears itself so the screen can show an error and ask again.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? error;
  final ValueChanged<String> onComplete;
  final VoidCallback? onBiometric;

  const PinPad({
    super.key,
    required this.title,
    required this.onComplete,
    this.subtitle,
    this.error,
    this.onBiometric,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _tap(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      final done = _pin;
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _pin = '');
        widget.onComplete(done);
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, color: AppColors.teal, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
          ],
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColors.teal : Colors.transparent,
                    border: Border.all(color: AppColors.teal, width: 1.6),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 38,
            child: Center(
              child: widget.error == null
                  ? null
                  : Text(
                      widget.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.red),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [for (final d in row) _digit(d)],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.onBiometric == null
                    ? const SizedBox(width: 92, height: 72)
                    : _iconKey(Icons.fingerprint, widget.onBiometric!),
                _digit('0'),
                _iconKey(Icons.backspace_outlined, _back),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _digit(String d) {
    return _key(
      onTap: () => _tap(d),
      child: Text(
        d,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _iconKey(IconData icon, VoidCallback onTap) {
    return _key(
      onTap: onTap,
      plain: true,
      child: Icon(icon, color: AppColors.teal, size: 28),
    );
  }

  Widget _key({
    required VoidCallback onTap,
    required Widget child,
    bool plain = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: plain ? Colors.transparent : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 72, height: 72, child: Center(child: child)),
        ),
      ),
    );
  }
}
