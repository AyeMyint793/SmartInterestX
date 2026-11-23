import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../providers/security_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_nav.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import 'export_backup_screen.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> _autoLockOptions = [
    'When you leave the app',
    'After 1 minute',
    'After 5 minutes',
  ];

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final security = context.watch<SecurityProvider>();
    final initials = _initials(ledger.userName);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            const Text(
              'Make it yours',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Settings & security',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 18),

            // Profile
            AppCard(
              radius: 22,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  InitialsAvatar(initials, size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ledger.userName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Personal ledger · INR (₹)',
                          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editName(context, ledger),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Protect your ledger
            const _Heading('Protect your ledger'),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingRow(
                    icon: Icons.lock_outline,
                    title: 'App PIN',
                    subtitle: security.pinEnabled
                        ? 'On · asked when you open the app'
                        : 'Set a 4-digit PIN',
                    trailing: AppSwitch(
                      value: security.pinEnabled,
                      onChanged: (v) async {
                        if (v) {
                          await PinSetupScreen.open(context);
                        } else {
                          await _removePin(context, security);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.fingerprint,
                    title: 'Biometric lock',
                    subtitle: 'Use Face ID or fingerprint',
                    trailing: AppSwitch(
                      value: security.biometricEnabled,
                      onChanged: security.pinEnabled
                          ? (v) async {
                              if (!v) {
                                await security.setBiometric(false);
                                return;
                              }
                              final available = await security.biometricAvailable();
                              if (!context.mounted) return;
                              if (!available) {
                                showMessage(
                                  context,
                                  'Set up a fingerprint or face unlock in your phone settings first.',
                                );
                                return;
                              }
                              final ok = await security.authenticateBiometric(
                                'Confirm to turn on biometric lock',
                              );
                              if (ok) await security.setBiometric(true);
                            }
                          : null,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.timer_outlined,
                    title: 'Auto-lock',
                    subtitle: security.autoLock,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGrey,
                    ),
                    onTap: () async {
                      final choice = await showOptionSheet(
                        context,
                        title: 'Auto-lock',
                        options: SecurityProvider.autoLockOptions,
                        selected: SecurityProvider.autoLockOptions
                            .indexOf(security.autoLock),
                      );
                      if (choice != null) {
                        await security.setAutoLock(
                          SecurityProvider.autoLockOptions[choice],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  const HintText(
                    'Security options · turn on a PIN before enabling biometrics on a supported device.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reminders
            const _Heading('Reminders'),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.notifications_none,
                    title: 'Due date reminders',
                    subtitle:
                        '${ledger.reminderDays} ${ledger.reminderDays == 1 ? 'day' : 'days'} before · 9:00 AM',
                    trailing: AppSwitch(
                      value: ledger.reminderEnabled,
                      onChanged: (v) =>
                          ledger.change(() => ledger.reminderEnabled = v),
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.error_outline,
                    title: 'Overdue alerts',
                    subtitle: 'Daily until the loan is settled',
                    trailing: AppSwitch(
                      value: ledger.overdueAlerts,
                      onChanged: (v) =>
                          ledger.change(() => ledger.overdueAlerts = v),
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.calendar_month_outlined,
                    title: 'Monthly summary',
                    subtitle: '1st of each month',
                    trailing: AppSwitch(
                      value: ledger.monthlySummary,
                      onChanged: (v) =>
                          ledger.change(() => ledger.monthlySummary = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data & preferences
            const _Heading('Data & preferences'),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.storage_outlined,
                    title: 'Export & backup',
                    subtitle: 'Download, back up or restore records',
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGrey,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExportBackupScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.calculate_outlined,
                    title: 'Interest calculation',
                    subtitle: 'Simple · 30/360 day convention',
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGrey,
                    ),
                    onTap: () => _info(
                      context,
                      'Interest calculation',
                      'SmartInterestX uses simple interest only, so interest is never added to the principal.\n\n'
                          'Monthly rate: whole calendar months count fully and part months use 30-day months.\n\n'
                          'Yearly rate: whole years count fully and part years use 360-day years.\n\n'
                          'Payments cover accrued interest first, then principal.',
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.help_outline,
                    title: 'Help & about',
                    subtitle: 'How your ledger works',
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGrey,
                    ),
                    onTap: () => _info(
                      context,
                      'How your ledger works',
                      'Add the people you lend to or borrow from, then record loans as Given (you lent) or Taken (you borrowed).\n\n'
                          'Record payments you have already made outside the app, attach a receipt if you like, and watch balances and interest update.\n\n'
                          'SmartInterestX is a record-keeping tool. It does not move money.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SoftButton(
              label: 'Log out',
              icon: Icons.logout,
              onPressed: () async {
                mainTab.value = 0;
                await context.read<SecurityProvider>().removePin();
                await AuthService().signOut();
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'SmartInterestX · Demo ledger\nA loan tracker, not a payment or lending service.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _removePin(BuildContext context, SecurityProvider security) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Turn off the PIN?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter your current PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || !context.mounted) return;
    if (security.verifyPin(pin)) {
      await security.removePin();
    } else {
      showMessage(context, 'Wrong PIN. The lock stays on.');
    }
  }

  void _info(BuildContext context, String title, String text) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, LedgerProvider ledger) async {
    final controller = TextEditingController(text: ledger.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      ledger.change(() => ledger.userName = name);
    }
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
