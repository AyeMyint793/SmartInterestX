import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_model.dart';
import '../providers/ledger_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import 'add_contact_screen.dart';
import 'loan_detail_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  int _tab = 0; // 0 all, 1 borrowers, 2 lenders

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final contacts = ledger.contacts;
    final borrowers = contacts.where((c) => c.type == 'borrower').length;
    final lenders = contacts.where((c) => c.type == 'lender').length;
    final q = _search.text.trim().toLowerCase();
    final digits = q.replaceAll(' ', '');

    final shown = contacts.where((c) {
      final tabOk = _tab == 0 ||
          (_tab == 1 && c.type == 'borrower') ||
          (_tab == 2 && c.type == 'lender');
      final queryOk = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.mobile.replaceAll(' ', '').contains(digits);
      return tabOk && queryOk;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'People in your ledger',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${contacts.length} contacts · ${ledger.loans.length} linked loans',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleIconButton(
                        icon: Icons.person_add_alt,
                        onTap: () => AddContactScreen.open(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search name or mobile number',
                      hintStyle: const TextStyle(color: AppColors.textGrey),
                      prefixIcon:
                      const Icon(Icons.search, color: AppColors.textGrey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 17),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentTabs(
                    options: [
                      'All · ${contacts.length}',
                      'Borrowers · $borrowers',
                      'Lenders · $lenders',
                    ],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 14),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No contacts found',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    ),
                  for (final c in shown) ...[
                    _contactCard(context, ledger, c),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: PrimaryButton(
                label: 'Add contact',
                icon: Icons.person_add_alt,
                onPressed: () => AddContactScreen.open(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, LedgerProvider ledger, Contact c) {
    final loans = ledger.loansOf(c.id);
    final receivable = loans
        .where((v) => v.isGiven)
        .fold<double>(0, (s, v) => s + v.balance);
    final payable = loans
        .where((v) => !v.isGiven)
        .fold<double>(0, (s, v) => s + v.balance);

    final hasGiven = loans.any((v) => v.isGiven);
    final hasTaken = loans.any((v) => !v.isGiven);

    String label;
    double amount;
    if (loans.isEmpty) {
      label = 'No loans yet';
      amount = 0;
    } else if (hasGiven && !hasTaken) {
      label = 'To receive';
      amount = receivable;
    } else if (hasTaken && !hasGiven) {
      label = 'To pay';
      amount = payable;
    } else if (receivable >= payable) {
      label = 'Net to receive';
      amount = receivable - payable;
    } else {
      label = 'Net to pay';
      amount = payable - receivable;
    }

    // "1 active, 1 settled"
    final counts = <String>[];
    for (final s in const ['Active', 'Partial', 'Overdue', 'Settled']) {
      final n = loans.where((v) => v.status == s).length;
      if (n > 0) counts.add('$n ${s.toLowerCase()}');
    }
    final summary = counts.isEmpty ? label : '$label · ${counts.join(', ')}';

    final ids = loans.map((v) => v.id).join(', ');
    final loanText = loans.isEmpty
        ? 'No linked loans'
        : '${loans.length} ${loans.length == 1 ? 'loan' : 'loans'} · $ids';

    final isBorrower = c.type == 'borrower';

    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => _showLoans(context, c, loans),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(c.initials),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.mobile,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textGrey),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Pill(
                c.typeLabel,
                background: isBorrower ? AppColors.mint : AppColors.greyBg,
                foreground: isBorrower ? AppColors.teal : AppColors.greyText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loanText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ),
              Text(
                formatRupees(amount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLoans(BuildContext context, Contact c, List<LoanView> loans) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
                child: Text(
                  '${c.name} · loans',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (loans.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Text(
                    'No loans linked to this contact yet.',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final v in loans)
                      ListTile(
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                        title: Text(
                          '${v.id} · ${v.loan.typeLabel}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(formatRupees(v.balance)),
                        trailing: StatusChip(v.status),
                        onTap: () {
                          Navigator.pop(ctx);
                          LoanDetailScreen.open(context, v.id);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
