import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/loan_card.dart';
import 'add_loan_screen.dart';
import 'loan_detail_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  static const List<String> _types = ['All', 'Given', 'Taken'];
  static const List<String> _statuses = [
    'All statuses',
    'Active',
    'Partial',
    'Settled',
    'Overdue',
  ];

  final _search = TextEditingController();
  int _type = 0;
  String _status = 'All statuses';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _search.clear();
      _type = 0;
      _status = 'All statuses';
    });
  }

  List<LoanView> _filter(List<LoanView> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((v) {
      final typeOk = _type == 0 || v.loan.typeLabel == _types[_type];
      final statusOk = _status == 'All statuses' || v.status == _status;
      final queryOk = q.isEmpty ||
          v.name.toLowerCase().contains(q) ||
          v.id.toLowerCase().contains(q);
      return typeOk && statusOk && queryOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final all = ledger.loans;
    final shown = _filter(all);

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
                              'Your loans',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${all.length} records · as of ${formatDate(ledger.today)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleIconButton(icon: Icons.tune, onTap: _reset),
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
                      hintText: 'Search a name or loan ID',
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
                    options: _types,
                    selected: _type,
                    onChanged: (i) => setState(() => _type = i),
                  ),
                  const SizedBox(height: 10),
                  const HintText('Given = you lent · Taken = you borrowed'),
                  const SizedBox(height: 10),
                  _statusChips(),
                  const SizedBox(height: 10),
                  const HintText('Balances include interest accrued to today.'),
                  const SizedBox(height: 12),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No loans found',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    ),
                  for (final v in shown) ...[
                    LoanCard(
                      view: v,
                      onTap: () => LoanDetailScreen.open(context, v.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: PrimaryButton(
                label: 'Add a loan',
                icon: Icons.add,
                onPressed: () => AddLoanScreen.open(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in _statuses)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _status = s),
                child: _chip(s),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String s) {
    final selected = _status == s;
    final overdue = s == 'Overdue';
    Color bg = AppColors.greyBg;
    Color fg = AppColors.greyText;
    if (overdue) {
      bg = AppColors.redBg;
      fg = AppColors.red;
    } else if (selected) {
      bg = AppColors.mint;
      fg = AppColors.teal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? fg : Colors.transparent),
      ),
      child: Text(
        s,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
