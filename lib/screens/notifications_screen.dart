import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';
import 'loan_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _allRead = false;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final today = ledger.today;
    final loans = ledger.loans;
    final days = ledger.reminderDays;

    // Needs your attention: overdue, due today, due within the reminder window.
    final alerts = <Widget>[];
    for (final v in loans) {
      final due = v.loan.due;
      if (v.isSettled || due == null) continue;
      final verb = v.isGiven ? 'to receive' : 'to pay';
      final left = daysBetween(today, due);

      if (v.status == 'Overdue' && ledger.overdueAlerts) {
        alerts.add(_alert(
          context,
          v,
          icon: Icons.error_outline,
          iconColor: AppColors.red,
          iconBg: AppColors.redBg,
          title: '${v.name} is ${v.overdueDays} days overdue',
          body:
              '${formatRupees(v.balance)} $verb today. Due ${formatShortDate(due)}; includes interest accrued since then.',
          meta: 'Overdue · ${v.id} · 9:00 AM',
          metaColor: AppColors.red,
        ));
      } else if (left == 0 && ledger.reminderEnabled) {
        alerts.add(_alert(
          context,
          v,
          icon: Icons.event_available_outlined,
          iconColor: AppColors.amberText,
          iconBg: AppColors.amberBg,
          title: '${v.name} is due today',
          body:
              '${formatRupees(v.balance)} $verb. Open the loan to review or record a payment ${v.isGiven ? 'received' : 'made'}.',
          meta: 'Due today · ${v.id} · 9:00 AM',
          metaColor: AppColors.amberText,
        ));
      } else if (left > 0 && left <= days && ledger.reminderEnabled) {
        alerts.add(_alert(
          context,
          v,
          icon: Icons.event_outlined,
          iconColor: AppColors.amberText,
          iconBg: AppColors.amberBg,
          title: '${v.name} is due in $left ${left == 1 ? 'day' : 'days'}',
          body: '${formatRupees(v.balance)} $verb on ${formatShortDate(due)}.',
          meta: 'Due soon · ${v.id} · 9:00 AM',
          metaColor: AppColors.amberText,
        ));
      }
    }

    // Upcoming: the next due date and what is projected on it.
    final future = loans
        .where((v) =>
            !v.isSettled && v.loan.due != null && v.loan.due!.isAfter(today))
        .toList()
      ..sort((a, b) => a.loan.due!.compareTo(b.loan.due!));
    Widget? nextDue;
    if (future.isNotEmpty) {
      final date = future.first.loan.due!;
      final same = future.where((v) => v.loan.due == date).toList();
      final lines = same
          .map((v) =>
              '${v.contact?.firstName ?? v.name}: ${formatRupees(v.projected.balance)} projected to ${v.isGiven ? 'receive' : 'pay'}.')
          .join(' ');
      final away = daysBetween(today, date);
      nextDue = _info(
        icon: Icons.calendar_month_outlined,
        title: 'Next due date: ${date.day.toString().padLeft(2, '0')} ${kMonthLong[date.month - 1]}',
        body: lines,
        meta: 'Upcoming · $away days away · no more payments assumed',
      );
    }

    // Last month's summary.
    final prevMonth = today.month == 1 ? 12 : today.month - 1;
    final prevYear = today.month == 1 ? today.year - 1 : today.year;
    final rows = ledger.splitRows(year: prevYear, month: prevMonth);
    final earned = ledger.sumInterest(rows, given: true);
    final paid = ledger.sumInterest(rows, given: false);
    final net = earned - paid;
    final summary = ledger.monthlySummary
        ? _info(
            icon: Icons.show_chart,
            title: 'Your ${kMonthLong[prevMonth - 1]} summary',
            body:
                '${formatRupees(earned)} interest earned and ${formatRupees(paid)} interest paid. Net ${net >= 0 ? 'received' : 'paid'}: ${formatRupees(net.abs())}.',
            meta: 'Monthly summary · recorded payments · 8:00 AM',
          )
        : null;

    return SubScreen(
      title: 'Stay ahead of dues',
      subtitle: 'Notifications · ${formatDate(today)}',
      trailing: CircleIconButton(
        icon: Icons.done_all,
        onTap: () {
          setState(() => _allRead = true);
          showMessage(context, 'All caught up');
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          _reminderCard(ledger),
          const SizedBox(height: 20),
          SectionTitle(
            'Needs your attention',
            action: _allRead
                ? 'All read'
                : '${alerts.length} ${alerts.length == 1 ? 'alert' : 'alerts'}',
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const AppCard(
              child: Text(
                'Nothing needs your attention right now.',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
          for (final a in alerts) ...[a, const SizedBox(height: 12)],
          const SizedBox(height: 8),
          const SectionTitle('Upcoming & summaries'),
          const SizedBox(height: 12),
          if (nextDue != null) ...[nextDue, const SizedBox(height: 12)],
          if (summary != null) ...[summary, const SizedBox(height: 12)],
          if (nextDue == null && summary == null)
            const AppCard(
              child: Text(
                'No upcoming dates or summaries.',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
          const SizedBox(height: 8),
          const HintText(
            'Reminders are for you. The app does not automatically contact borrowers or lenders.',
          ),
        ],
      ),
    );
  }

  Widget _reminderCard(LedgerProvider ledger) {
    return AppCard(
      color: AppColors.mint,
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before a loan is due',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose when you want a reminder',
                      style: TextStyle(fontSize: 14, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: ledger.reminderEnabled,
                onChanged: (v) => ledger.change(() => ledger.reminderEnabled = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final d in const [1, 3, 7]) ...[
                Expanded(child: _dayButton(ledger, d)),
                if (d != 7) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ledger.reminderEnabled
                ? '${ledger.reminderDays} ${ledger.reminderDays == 1 ? 'day' : 'days'} before due · at 9:00 AM'
                : 'Reminders are off',
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              await NotificationService.requestPermission();
              await NotificationService.showNow(
                title: 'SmartInterestX reminder',
                body: 'This is how your due-date reminders will look.',
              );
            },
            child: const Text(
              'Send a test reminder',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayButton(LedgerProvider ledger, int d) {
    final selected = ledger.reminderDays == d;
    return GestureDetector(
      onTap: () => ledger.change(() => ledger.reminderDays = d),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 18, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              '$d ${d == 1 ? 'day' : 'days'}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alert(
    BuildContext context,
    LoanView v, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String body,
    required String meta,
    required Color metaColor,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: () => LoanDetailScreen.open(context, v.id),
      child: _notificationBody(
        icon: icon,
        iconColor: iconColor,
        iconBg: iconBg,
        title: title,
        body: body,
        meta: meta,
        metaColor: metaColor,
      ),
    );
  }

  Widget _info({
    required IconData icon,
    required String title,
    required String body,
    required String meta,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: _notificationBody(
        icon: icon,
        iconColor: AppColors.teal,
        iconBg: AppColors.mint,
        title: title,
        body: body,
        meta: meta,
        metaColor: AppColors.teal,
      ),
    );
  }

  Widget _notificationBody({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String body,
    required String meta,
    required Color metaColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: _allRead ? FontWeight.w600 : FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meta,
                style: TextStyle(fontSize: 12, color: metaColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
