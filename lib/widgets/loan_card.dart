import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'app_widgets.dart';

class LoanCard extends StatelessWidget {
  final LoanView view;
  final bool relativeDue; // true: "due today", false: "due 01 Oct"
  final VoidCallback? onTap;

  const LoanCard({
    super.key,
    required this.view,
    this.relativeDue = false,
    this.onTap,
  });

  String _terms(DateTime today) {
    final l = view.loan;
    if (view.isSettled) {
      final date = view.lastPaymentDate;
      final verb = l.isGiven ? 'received' : 'paid';
      final amount = formatRupees(view.now.totalPaid);
      final when = date == null ? '' : ' · ${formatShortDate(date)}';
      return '$amount $verb$when';
    }
    final rate = '${formatRate(l.rate)}% ${l.monthly ? 'monthly' : 'yearly'}';
    final due = l.due;
    if (due == null) return '$rate · no due date';
    final dueText = relativeDue ? dueLabel(due, today) : 'due ${formatShortDate(due)}';
    return '$rate · $dueText';
  }

  @override
  Widget build(BuildContext context) {
    final today = context.read<LedgerProvider>().today;
    final chipLabel = view.status == 'Overdue'
        ? 'Overdue · ${view.overdueDays}d'
        : view.status;

    return AppCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              InitialsAvatar(view.initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${view.id} · ${view.loan.typeLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupees(view.balance),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _terms(today),
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ),
              StatusChip(view.status, label: chipLabel),
            ],
          ),
        ],
      ),
    );
  }
}
