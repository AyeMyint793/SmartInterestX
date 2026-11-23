import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../providers/security_provider.dart';
import '../services/export_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';

class ExportBackupScreen extends StatefulWidget {
  const ExportBackupScreen({super.key});

  @override
  State<ExportBackupScreen> createState() => _ExportBackupScreenState();
}

class _ExportBackupScreenState extends State<ExportBackupScreen> {
  int _format = 1; // 0 CSV, 1 Excel
  int _range = 0; // 0 all time, 1 this year, 2 last 30 days
  int _provider = 1; // 0 Google Drive, 1 Firebase
  bool _busy = false;

  static const List<String> _rangeNames = [
    'All time',
    'This year',
    'Last 30 days',
  ];

  List<LoanView> _filtered(LedgerProvider ledger) {
    final today = ledger.today;
    final all = ledger.loans;
    switch (_range) {
      case 1:
        return all.where((v) => v.loan.start.year == today.year).toList();
      case 2:
        return all
            .where((v) => daysBetween(v.loan.start, today) <= 30)
            .toList();
      default:
        return all;
    }
  }

  String _rangeLabel(DateTime today) {
    switch (_range) {
      case 1:
        return 'This year · 01 Jan – ${formatDate(today)}';
      case 2:
        final from = today.subtract(const Duration(days: 30));
        return 'Last 30 days · ${formatShortDate(from)} – ${formatDate(today)}';
      default:
        return 'All time · through ${formatDate(today)}';
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<SecurityProvider>().guard(action);
    } catch (e) {
      if (mounted) showMessage(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSpreadsheet(LedgerProvider ledger) => _run(() async {
        final views = _filtered(ledger);
        if (views.isEmpty) {
          showMessage(context, 'There are no loans in this date range.');
          return;
        }
        final now = DateTime.now();
        if (_format == 0) {
          await ExportService.shareCsv(ledger.loanTable(views), now);
        } else {
          await ExportService.shareExcel(
            ledger.loanTable(views),
            ledger.paymentTable(views),
            now,
          );
        }
      });

  Future<void> _createBackup(LedgerProvider ledger) => _run(() async {
        await ExportService.saveAndShareBackup(
          ledger.backupJson(),
          DateTime.now(),
        );
        ledger.markBackupDone();
        if (mounted) {
          showMessage(context, 'Backup created. Keep the file somewhere safe.');
        }
      });

  Future<void> _restore(LedgerProvider ledger) => _run(() async {
        final picked = await FilePicker.platform.pickFiles(type: FileType.any);
        final path = picked?.files.single.path;
        if (path == null) return;

        final text = await File(path).readAsString();
        int contacts, loans, payments;
        String? created;
        try {
          final data = jsonDecode(text) as Map<String, dynamic>;
          contacts = (data['contacts'] as List).length;
          loans = (data['loans'] as List).length;
          payments = (data['payments'] as List).length;
          created = data['createdAt'] as String?;
        } catch (_) {
          if (mounted) {
            showMessage(context, 'This file is not a SmartInterestX backup.');
          }
          return;
        }

        if (!mounted) return;
        final when = created == null ? null : DateTime.tryParse(created);
        final sure = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Restore this backup?'),
            content: Text(
              '${when == null ? 'Backup file' : 'Backup from ${formatDate(when)} ${formatTime(when)}'}\n'
              '$loans loans · $contacts contacts · $payments payments\n\n'
              'This replaces everything in your current ledger.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Replace my ledger',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
            ],
          ),
        );
        if (sure != true) return;

        final error = await ledger.restoreFromBackup(text);
        if (mounted) {
          showMessage(context, error ?? 'Ledger restored from the backup.');
        }
      });

  void _cloudInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cloud backup is on'),
        content: const Text(
          'Your contacts, loans and payments are saved in your Firebase account every time you change them.\n\n'
          'Log in on any phone with the same account and your ledger is there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final today = ledger.today;
    final shown = _filtered(ledger);
    final last = ledger.lastBackup;

    return SubScreen(
      title: 'Your records, with you',
      subtitle: 'Export & backup',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          // Last backup
          AppCard(
            color: AppColors.mint,
            radius: 24,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.save_outlined, color: AppColors.teal, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last local backup',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            last == null
                                ? 'No backup yet'
                                : '${formatDate(last)} · ${formatTime(last)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (last != null)
                      const Text(
                        'Saved',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${ledger.loans.length} loans · ${ledger.contacts.length} contacts · ${ledger.paymentCount} payment records\nIncludes payment proof details',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Spreadsheet
          const _Heading('Export a spreadsheet'),
          AppCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share a readable copy with your accountant or keep it for your own records.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textGrey),
                ),
                const SizedBox(height: 16),
                SegmentTabs(
                  options: const ['CSV (.csv)', 'Excel (.xlsx)'],
                  selected: _format,
                  onChanged: (i) => setState(() => _format = i),
                ),
                const SizedBox(height: 16),
                PickerField(
                  label: 'Date range',
                  value: _rangeLabel(today),
                  icon: Icons.keyboard_arrow_down,
                  onTap: () async {
                    final choice = await showOptionSheet(
                      context,
                      title: 'Date range',
                      options: _rangeNames,
                      selected: _range,
                    );
                    if (choice != null) setState(() => _range = choice);
                  },
                ),
                const SizedBox(height: 10),
                const HintText(
                  'Includes loan terms, balances and payment history. Receipt images are included in backups, not spreadsheets.',
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _busy
                      ? 'Preparing…'
                      : 'Export ${shown.length} ${shown.length == 1 ? 'loan' : 'loans'}',
                  icon: Icons.file_download_outlined,
                  onPressed: _busy ? null : () => _exportSpreadsheet(ledger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Backups
          const _Heading('Back up your ledger'),
          AppCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BackupHeader(
                  icon: Icons.smartphone,
                  title: 'On this device',
                  subtitle: 'Save a full backup file locally',
                ),
                const SizedBox(height: 14),
                SoftButton(
                  label: 'Create local backup',
                  icon: Icons.save_alt,
                  onPressed: _busy ? null : () => _createBackup(ledger),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                _BackupHeader(
                  icon: Icons.cloud_outlined,
                  title: 'Cloud backup · optional',
                  subtitle: _provider == 1
                      ? 'Connected · Firebase (automatic)'
                      : 'Not connected · choose a provider',
                ),
                const SizedBox(height: 14),
                SegmentTabs(
                  options: const ['Google Drive', 'Firebase'],
                  selected: _provider,
                  onChanged: (i) => setState(() => _provider = i),
                ),
                const SizedBox(height: 10),
                HintText(
                  _provider == 1
                      ? 'Your ledger is saved in your Firebase account whenever you make a change.'
                      : 'Google Drive backup is not included. Firebase backup is already on.',
                ),
                const SizedBox(height: 14),
                SoftButton(
                  label: _provider == 1
                      ? 'Cloud backup is on'
                      : 'Use Firebase backup',
                  icon: Icons.cloud_done_outlined,
                  onPressed: _provider == 1
                      ? _cloudInfo
                      : () => setState(() => _provider = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Restore
          AppCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: AppColors.textDark),
                    SizedBox(width: 12),
                    Text(
                      'Restore from a backup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose a saved file. Review its date and contents before replacing your current ledger.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textGrey),
                ),
                const SizedBox(height: 14),
                SoftButton(
                  label: 'Choose backup to restore',
                  onPressed: _busy ? null : () => _restore(ledger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const HintText(
            'Store backup files safely. They contain personal contact details and financial records.',
          ),
        ],
      ),
    );
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

class _BackupHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BackupHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.teal, size: 26),
        const SizedBox(width: 14),
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
        const Icon(Icons.chevron_right, color: AppColors.textGrey),
      ],
    );
  }
}
