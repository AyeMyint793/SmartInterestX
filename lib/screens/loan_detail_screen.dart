import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/payment_model.dart';
import '../providers/ledger_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/interest_calculator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import 'add_loan_screen.dart';
import 'record_payment_screen.dart';

class LoanDetailScreen extends StatelessWidget {
  final String loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  static void open(BuildContext context, String loanId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loanId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final v = ledger.loanById(loanId);
    if (v == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('Loan not found'))),
      );
    }

    final today = ledger.today;
    final l = v.loan;
    final received = l.isGiven;
    final due = l.due;
    final showProjection =
        due != null && due.isAfter(today) && !v.isSettled;
    final statusText = switch (v.status) {
      'Partial' => 'Partially paid',
      'Overdue' => 'Overdue · ${v.overdueDays}d',
      _ => v.status,
    };

    return SubScreen(
      title: 'Loan details',
      subtitle: '${v.id} · as of ${formatDate(today)}',
      trailing: CircleIconButton(
        icon: Icons.edit_outlined,
        onTap: () => _showMenu(context, ledger),
      ),
      bottom: v.isSettled
          ? null
          : PrimaryButton(
              label: received ? 'Record payment received' : 'Record payment made',
              onPressed: () => RecordPaymentScreen.open(context, v.id),
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        children: [
          // Contact row
          Row(
            children: [
              InitialsAvatar(v.initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${v.contact?.mobile ?? ''} · View contact',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Pill(
                l.typeLabel,
                background: AppColors.mint,
                foreground: AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dark balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REMAINING ${received ? 'RECEIVABLE' : 'PAYABLE'} · TODAY',
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  formatRupees(v.balance),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(v.status, label: statusText),
                    if (due != null)
                      Pill(
                        'Due ${formatDate(due)}',
                        background: AppColors.greyBg,
                        foreground: AppColors.greyText,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${formatRupees(l.principal)} principal + ${formatRupees(v.now.accrued)} interest − ${formatRupees(v.now.totalPaid)} ${received ? 'received' : 'paid'}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Loan terms
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loan terms',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                KeyValueRow('Original principal', formatRupees(l.principal)),
                KeyValueRow(
                  'Simple interest',
                  '${formatRate(l.rate)}% ${l.monthly ? 'monthly' : 'yearly'}',
                ),
                KeyValueRow('Started', formatDate(l.start)),
                KeyValueRow('Due date', due == null ? 'Not set' : formatDate(due)),
                if (l.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    l.notes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interest & balance
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Interest & balance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                KeyValueRow(
                  'Accrued till today · ${InterestCalculator.periodLabel(l.start, today, l.monthly)}',
                  formatRupees(v.now.accrued),
                ),
                KeyValueRow(
                  'Interest ${received ? 'received' : 'paid'} so far',
                  formatRupees(v.now.interestPaid),
                  valueColor: AppColors.teal,
                ),
                KeyValueRow(
                  'Unpaid interest today',
                  formatRupees(v.now.unpaidInterest),
                ),
                if (showProjection) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  KeyValueRow(
                    'Projected interest till due date',
                    formatRupees(v.projected.accrued),
                  ),
                  KeyValueRow(
                    'Total ${received ? 'receivable' : 'payable'} at due date',
                    formatRupees(l.principal + v.projected.accrued),
                  ),
                  KeyValueRow(
                    'Amount already ${received ? 'received' : 'paid'}',
                    '− ${formatRupees(v.now.totalPaid)}',
                  ),
                  KeyValueRow(
                    'Projected balance at due date',
                    formatRupees(v.projected.balance),
                    valueColor: AppColors.teal,
                  ),
                  const SizedBox(height: 8),
                  const HintText(
                    'Projection assumes no more payments. Interest uses 30-day months and continues until settlement. Payments cover interest first, then principal.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Payment history
          SectionTitle(
            'Payment history',
            action:
                '${v.payments.length} ${v.payments.length == 1 ? 'record' : 'records'}',
          ),
          const SizedBox(height: 12),
          if (v.payments.isEmpty)
            const AppCard(
              child: Text(
                'No payments recorded yet.',
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  for (final s in v.now.splits.reversed)
                    _paymentRow(context, ledger, s, received),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentRow(
    BuildContext context,
    LedgerProvider ledger,
    PaymentSplit s,
    bool received,
  ) {
    final p = s.payment;
    String kind;
    if (s.interest > 0 && s.principal > 0) {
      kind = 'Interest & principal';
    } else if (s.interest > 0) {
      kind = 'Interest';
    } else {
      kind = 'Principal';
    }
    return InkWell(
      onTap: () => _paymentMenu(context, ledger, p),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, right: 16),
            child: Icon(
              received ? Icons.south_west : Icons.north_east,
              size: 18,
              color: AppColors.teal,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(p.date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.mode} · $kind ${received ? 'received' : 'paid'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
                if (p.hasProof)
                  GestureDetector(
                    onTap: () => _showProof(context, p),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Receipt attached · View proof',
                        style: TextStyle(fontSize: 12, color: AppColors.teal),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              formatRupees(p.amount),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _paymentMenu(
    BuildContext context,
    LedgerProvider ledger,
    Payment p,
  ) async {
    final choice = await showOptionSheet(
      context,
      title: '${formatDate(p.date)} · ${formatRupees(p.amount)}',
      options: const ['Edit payment', 'Delete payment'],
    );
    if (choice == null || !context.mounted) return;
    if (choice == 0) {
      RecordPaymentScreen.open(context, loanId, paymentId: p.id);
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete this payment?'),
        content: const Text(
          'The balance and interest will be recalculated without it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (sure == true) ledger.deletePayment(p.id);
  }

  void _showProof(BuildContext context, Payment p) {
    final path = p.proofPath;
    final data = p.proofData;
    final hasFile = path != null && File(path).existsSync();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(p.proofName ?? 'Payment proof'),
        content: (data != null && data.isNotEmpty)
            ? Image.memory(base64Decode(data), fit: BoxFit.contain)
            : hasFile
                ? Image.file(File(path!), fit: BoxFit.contain)
                : const Text('No photo was saved with this payment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, LedgerProvider ledger) async {
    final choice = await showOptionSheet(
      context,
      title: 'Loan options',
      options: const ['Edit loan', 'Delete this loan'],
    );
    if (choice == null || !context.mounted) return;
    if (choice == 0) {
      AddLoanScreen.open(context, editLoanId: loanId);
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete this loan?'),
        content: const Text(
          'The loan and its payment history will be removed from your ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (sure == true && context.mounted) {
      Navigator.pop(context);
      ledger.deleteLoan(loanId);
    }
  }
}
