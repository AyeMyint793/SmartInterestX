import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';
import 'export_backup_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _month = 0; // 0 = all months, 1..12
  late int _year;
  String? _contactId; // null = everyone

  @override
  void initState() {
    super.initState();
    _year = context.read<LedgerProvider>().today.year;
  }

  List<int> _years(LedgerProvider ledger) {
    final set = <int>{ledger.today.year};
    for (final v in ledger.loans) {
      set.add(v.loan.start.year);
      for (final p in v.payments) {
        set.add(p.date.year);
      }
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  Future<void> _pickMonth() async {
    final choice = await showOptionSheet(
      context,
      title: 'Month',
      options: ['All months', ...kMonthLong],
      selected: _month,
    );
    if (choice != null) setState(() => _month = choice);
  }

  Future<void> _pickYear(List<int> years) async {
    final choice = await showOptionSheet(
      context,
      title: 'Year',
      options: years.map((y) => '$y').toList(),
      selected: years.indexOf(_year),
    );
    if (choice != null) setState(() => _year = years[choice]);
  }

  Future<void> _pickContact(LedgerProvider ledger) async {
    final contacts = ledger.contacts;
    final choice = await showOptionSheet(
      context,
      title: 'Contact',
      options: ['Everyone', ...contacts.map((c) => c.name)],
      selected: _contactId == null
          ? 0
          : contacts.indexWhere((c) => c.id == _contactId) + 1,
    );
    if (choice == null) return;
    setState(() => _contactId = choice == 0 ? null : contacts[choice - 1].id);
  }

  String _rangeText(DateTime today) {
    if (_month != 0) {
      final last = DateTime(_year, _month + 1, 0).day;
      return '01 ${kMonthShort[_month - 1]} – $last ${kMonthShort[_month - 1]} $_year';
    }
    if (_year == today.year) return '01 Jan – ${formatDate(today)}';
    return '01 Jan – 31 Dec $_year';
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final years = _years(ledger);
    if (!years.contains(_year)) years.add(_year);

    // Interest cards follow all three filters.
    final rows = ledger.splitRows(
      year: _year,
      month: _month == 0 ? null : _month,
      contactId: _contactId,
    );
    final earned = ledger.sumInterest(rows, given: true);
    final paid = ledger.sumInterest(rows, given: false);

    // Given vs Taken: original principal of loans (settled included).
    final loans = ledger.loans
        .where((v) =>
    (_contactId == null || v.loan.contactId == _contactId) &&
        v.loan.start.year <= _year)
        .toList();
    final givenTotal = loans
        .where((v) => v.isGiven)
        .fold<double>(0, (s, v) => s + v.loan.principal);
    final takenTotal = loans
        .where((v) => !v.isGiven)
        .fold<double>(0, (s, v) => s + v.loan.principal);
    final total = givenTotal + takenTotal;
    final givenPct = total == 0 ? 0 : (givenTotal / total * 100).round();
    final takenPct = total == 0 ? 0 : 100 - givenPct;

    final contactName = _contactId == null
        ? 'Everyone'
        : (ledger.contactById(_contactId!)?.name ?? 'Everyone');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'See the bigger picture',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your ledger, translated into insights',
                        style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CircleIconButton(
                  icon: Icons.file_download_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExportBackupScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _filterBox(
                    'Month',
                    _month == 0 ? 'All months' : kMonthLong[_month - 1],
                    _pickMonth,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _filterBox('Year', '$_year', () => _pickYear(years)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _filterBox(
                    'Contact',
                    contactName,
                        () => _pickContact(ledger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${_rangeText(ledger.today)} · recorded payments only',
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _interestCard(
                    'Interest earned',
                    earned,
                    'Received, not projected',
                    highlight: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _interestCard(
                    'Interest paid',
                    paid,
                    'Paid, not projected',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _givenVsTaken(givenTotal, takenTotal, total, givenPct, takenPct, loans.length),
            const SizedBox(height: 16),
            _monthlyFlow(ledger),
            const SizedBox(height: 16),
            _netCard(earned, paid),
          ],
        ),
      ),
    );
  }

  Widget _filterBox(String label, String value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textGrey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _interestCard(
      String title,
      double amount,
      String caption, {
        bool highlight = false,
      }) {
    return AppCard(
      color: highlight ? AppColors.mint : Colors.white,
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: highlight ? AppColors.teal : AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatRupees(amount),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            caption,
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _givenVsTaken(
      double given,
      double taken,
      double total,
      num givenPct,
      num takenPct,
      int loanCount,
      ) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Given vs Taken',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Original principal · includes settled loans',
            style: TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: _DonutPainter(
                        total == 0 ? 0 : given / total,
                        total == 0,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatLakh(total),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '$loanCount ${loanCount == 1 ? 'loan' : 'loans'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legend('Given · $givenPct%', given, AppColors.teal),
                    const SizedBox(height: 18),
                    _legend('Taken · $takenPct%', taken, AppColors.chartGrey),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatRupees(amount),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _monthlyFlow(LedgerProvider ledger) {
    final yearRows = ledger.splitRows(year: _year, contactId: _contactId);
    final earnedBy = List<double>.filled(12, 0);
    final paidBy = List<double>.filled(12, 0);
    for (final r in yearRows) {
      final m = r.split.payment.date.month - 1;
      if (r.view.isGiven) {
        earnedBy[m] += r.split.interest;
      } else {
        paidBy[m] += r.split.interest;
      }
    }

    // Show four months, ending with the latest month that has activity.
    var lastActive = -1;
    for (var m = 0; m < 12; m++) {
      if (earnedBy[m] > 0 || paidBy[m] > 0) lastActive = m;
    }
    if (lastActive < 0) {
      lastActive = _year == ledger.today.year ? ledger.today.month - 1 : 11;
    }
    var first = lastActive - 3;
    if (first < 0) first = 0;
    final months = [for (var m = first; m <= first + 3 && m < 12; m++) m];

    final labels = months.map((m) => kMonthShort[m]).toList();
    final e = months.map((m) => earnedBy[m]).toList();
    final p = months.map((m) => paidBy[m]).toList();

    final listed = months.where((m) => earnedBy[m] > 0 || paidBy[m] > 0).toList();
    var otherEarned = 0.0;
    var otherPaid = 0.0;
    for (var m = 0; m < 12; m++) {
      if (!listed.contains(m)) {
        otherEarned += earnedBy[m];
        otherPaid += paidBy[m];
      }
    }

    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly interest flow',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _dot(AppColors.teal),
              const SizedBox(width: 6),
              const Text('Earned', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
              const SizedBox(width: 16),
              _dot(AppColors.chartGrey),
              const SizedBox(width: 6),
              const Text('Paid', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
              const SizedBox(width: 16),
              const Text('INR', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(painter: _BarsPainter(labels, e, p)),
          ),
          const SizedBox(height: 14),
          for (final m in listed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${kMonthLong[m]} · earned / paid',
                      style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                    ),
                  ),
                  Text(
                    '${formatRupees(earnedBy[m])} / ${formatRupees(paidBy[m])}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          HintText(
            'Other months: ${formatRupees(otherEarned)} earned / ${formatRupees(otherPaid)} paid.',
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _netCard(double earned, double paid) {
    final net = earned - paid;
    final received = net >= 0;
    return AppCard(
      color: AppColors.mint,
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatRupees(net.abs())} net interest ${received ? 'received' : 'paid'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Earned minus paid. Projected interest and unpaid accruals are not included.',
            style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double givenFraction;
  final bool empty;

  _DonutPainter(this.givenFraction, this.empty);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 24.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.chartGrey;
    canvas.drawArc(rect, 0, 2 * pi, false, base);
    if (!empty) {
      final given = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.teal;
      canvas.drawArc(rect, -pi / 2, 2 * pi * givenFraction, false, given);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.givenFraction != givenFraction || old.empty != empty;
}

class _BarsPainter extends CustomPainter {
  final List<String> labels;
  final List<double> earned;
  final List<double> paid;

  _BarsPainter(this.labels, this.earned, this.paid);

  double _niceTop(double maxValue) {
    if (maxValue <= 0) return 800;
    final mag = pow(10, (log(maxValue) / ln10).floor()).toDouble();
    for (final m in [1, 2, 4, 5, 8, 10]) {
      if (m * mag >= maxValue) return m * mag;
    }
    return 10 * mag;
  }

  void _text(Canvas canvas, String s, Offset at,
      {double fontSize = 11, bool centered = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: fontSize, color: AppColors.textGrey),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centered ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const bottom = 26.0;
    final chartH = size.height - bottom;
    final chartW = size.width - left;

    var maxValue = 0.0;
    for (var i = 0; i < labels.length; i++) {
      if (earned[i] > maxValue) maxValue = earned[i];
      if (paid[i] > maxValue) maxValue = paid[i];
    }
    final top = _niceTop(maxValue);

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chartH - chartH * i / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _text(canvas, plainNumber(top * i / 2), Offset(0, y - 7));
    }

    final groupW = chartW / labels.length;
    const barW = 14.0;
    final earnedPaint = Paint()..color = AppColors.teal;
    final paidPaint = Paint()..color = AppColors.chartGrey;

    RRect bar(double x, double h) => RRect.fromRectAndCorners(
      Rect.fromLTWH(x, chartH - h, barW, h),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );

    for (var i = 0; i < labels.length; i++) {
      final cx = left + groupW * i + groupW / 2;
      final eh = earned[i] <= 0 ? 2.0 : chartH * earned[i] / top;
      final ph = paid[i] <= 0 ? 2.0 : chartH * paid[i] / top;
      canvas.drawRRect(bar(cx - barW - 2, eh), earnedPaint);
      canvas.drawRRect(bar(cx + 2, ph), paidPaint);
      _text(canvas, labels[i], Offset(cx, chartH + 8), centered: true);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => true;
}
