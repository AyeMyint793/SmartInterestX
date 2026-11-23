import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../utils/app_clock.dart';
import '../utils/app_colors.dart';
import '../utils/app_nav.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/loan_card.dart';
import 'add_loan_screen.dart';
import 'loan_detail_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final today = ledger.today;
    final loans = ledger.loans;

    final upcoming = loans
        .where((v) =>
            !v.isSettled && v.loan.due != null && !v.loan.due!.isBefore(today))
        .toList()
      ..sort((a, b) => a.loan.due!.compareTo(b.loan.due!));
    final overdue = loans.where((v) => v.status == 'Overdue').toList();
    final recent = loans.take(2).toList();
    final firstName = ledger.userName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, firstName, today),
              if (ledger.error != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  color: AppColors.redBg,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Sync problem: ${ledger.error}',
                    style: const TextStyle(fontSize: 12, color: AppColors.red),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _balanceCard(ledger),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _statCard('Interest earned', ledger.interestEarned),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard('Interest paid', ledger.interestPaid),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Add a loan',
                icon: Icons.add,
                onPressed: () => AddLoanScreen.open(context),
              ),
              const SizedBox(height: 24),
              SectionTitle(
                'Upcoming dues',
                action: 'View reminders',
                onAction: () => NotificationsScreen.open(context),
              ),
              const SizedBox(height: 12),
              _dueCard(
                context,
                upcoming.isEmpty ? null : upcoming.first,
                overdue,
                today,
              ),
              const SizedBox(height: 24),
              SectionTitle(
                'Recent loans',
                action: loans.isEmpty ? null : 'See all ${loans.length}',
                onAction: () => mainTab.value = 1,
              ),
              const SizedBox(height: 12),
              if (!ledger.ready)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (ledger.ready && loans.isEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your ledger is empty. Add your first loan, or load the sample ledger to explore the app.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SoftButton(
                        label: 'Load sample ledger',
                        onPressed: () => ledger.loadSampleData(),
                      ),
                    ],
                  ),
                ),
              for (final v in recent) ...[
                LoanCard(
                  view: v,
                  relativeDue: true,
                  onTap: () => LoanDetailScreen.open(context, v.id),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String firstName, DateTime today) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your money, in focus',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hello, $firstName · ${AppClock.useDemoDate ? 'demo ' : ''}as of ${formatDate(today)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CircleIconButton(
          icon: Icons.notifications_none,
          onTap: () => NotificationsScreen.open(context),
        ),
      ],
    );
  }

  Widget _balanceCard(LedgerProvider ledger) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outstanding receivables',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Icon(Icons.south_west, size: 18, color: AppColors.tealLight),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            formatRupees(ledger.receivables),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Outstanding payables',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Text(
                formatRupees(ledger.payables),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Includes accrued interest, less payments recorded.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, double amount) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
          ),
          const SizedBox(height: 10),
          Text(
            formatRupees(amount),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Recorded payments · all time',
            style: TextStyle(fontSize: 11, color: AppColors.teal),
          ),
        ],
      ),
    );
  }

  Widget _dueCard(
    BuildContext context,
    LoanView? next,
    List<LoanView> overdue,
    DateTime today,
  ) {
    if (next == null && overdue.isEmpty) {
      return const AppCard(
        child: Text(
          'Nothing is due right now.',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    final children = <Widget>[];

    if (next != null) {
      final due = next.loan.due!;
      children.add(
        InkWell(
          onTap: () => LoanDetailScreen.open(context, next.id),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.amberBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      due.day.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amberText,
                      ),
                    ),
                    Text(
                      kMonthShort[due.month - 1].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.amberText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${next.loan.typeLabel} · ${next.id} · ${dueLabel(due, today)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupees(next.balance),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (next != null && overdue.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(const Divider(height: 1));
      children.add(const SizedBox(height: 12));
    }

    if (overdue.isNotEmpty) {
      final v = overdue.first;
      final first = v.contact?.firstName ?? v.name;
      children.add(
        InkWell(
          onTap: () => LoanDetailScreen.open(context, v.id),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$first’s loan is ${v.overdueDays} days overdue. Review it.',
                  style: const TextStyle(fontSize: 13, color: AppColors.red),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(child: Column(children: children));
  }
}
