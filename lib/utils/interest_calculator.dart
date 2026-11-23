import '../models/loan_model.dart';
import '../models/payment_model.dart';
import 'formatters.dart';

/// How one payment was split: interest is covered first, then principal.
class PaymentSplit {
  final Payment payment;
  final double interest;
  final double principal;

  const PaymentSplit(this.payment, this.interest, this.principal);
}

/// State of a loan on a given date.
class LedgerSnapshot {
  final double principalOutstanding;
  final double accrued; // interest accrued since the loan started
  final double interestPaid;
  final double principalRepaid;
  final double totalPaid;
  final List<PaymentSplit> splits;

  const LedgerSnapshot({
    required this.principalOutstanding,
    required this.accrued,
    required this.interestPaid,
    required this.principalRepaid,
    required this.totalPaid,
    required this.splits,
  });

  double get unpaidInterest {
    final v = accrued - interestPaid;
    return v < 0 ? 0 : v;
  }

  double get balance => principalOutstanding + unpaidInterest;

  bool get isSettled => principalOutstanding <= 0.005 && unpaidInterest <= 0.005;
}

/// Simple interest only (no compounding).
/// Monthly rate: whole calendar months count fully, part months use 30-day months.
/// Yearly rate: whole years count fully, part years use 360-day years.
class InterestCalculator {
  static DateTime _d(DateTime x) => DateTime.utc(x.year, x.month, x.day);

  static double _r2(double v) => (v * 100).round() / 100;

  static int _wholeMonths(DateTime from, DateTime to) {
    var m = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) m--;
    return m < 0 ? 0 : m;
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, d.day > lastDay ? lastDay : d.day);
  }

  static double _periods(DateTime from, DateTime to, bool monthly) {
    final months = _wholeMonths(from, to);
    if (monthly) {
      final anchor = _addMonths(from, months);
      return months + to.difference(anchor).inDays / 30;
    }
    final years = months ~/ 12;
    final anchor = _addMonths(from, years * 12);
    return years + to.difference(anchor).inDays / 360;
  }

  /// Interest on [principal] between two dates.
  static double interest({
    required double principal,
    required double rate,
    required bool monthly,
    required DateTime from,
    required DateTime to,
  }) {
    final f = _d(from);
    final t = _d(to);
    if (principal <= 0 || rate <= 0 || !t.isAfter(f)) return 0;
    return _r2(principal * rate / 100 * _periods(f, t, monthly));
  }

  /// "3 months", "3 months 5 days", "12 days" ...
  static String periodLabel(DateTime from, DateTime to, bool monthly) {
    final f = _d(from);
    final t = _d(to);
    if (!t.isAfter(f)) return '0 days';
    final months = _wholeMonths(f, t);
    if (monthly) {
      final days = t.difference(_addMonths(f, months)).inDays;
      return _join(months, 'month', days);
    }
    final years = months ~/ 12;
    final days = t.difference(_addMonths(f, years * 12)).inDays;
    return _join(years, 'year', days);
  }

  static String _join(int units, String name, int days) {
    final parts = <String>[];
    if (units > 0) parts.add('$units $name${units == 1 ? '' : 's'}');
    if (days > 0) parts.add('$days day${days == 1 ? '' : 's'}');
    return parts.isEmpty ? '0 days' : parts.join(' ');
  }

  /// Replays the loan up to [asOf], applying payments in date order.
  static LedgerSnapshot replay(Loan loan, List<Payment> payments, DateTime asOf) {
    final end = _d(asOf);
    final sorted = payments.where((p) => !_d(p.date).isAfter(end)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    var principal = loan.principal;
    var accrued = 0.0;
    var interestPaid = 0.0;
    var principalRepaid = 0.0;
    var totalPaid = 0.0;
    var last = _d(loan.start);
    final splits = <PaymentSplit>[];

    for (final p in sorted) {
      final pd = _d(p.date);
      if (pd.isAfter(last)) {
        accrued += interest(
          principal: principal,
          rate: loan.rate,
          monthly: loan.monthly,
          from: last,
          to: pd,
        );
        last = pd;
      }
      final unpaid = accrued - interestPaid < 0 ? 0.0 : accrued - interestPaid;
      final toInterest = p.amount < unpaid ? p.amount : unpaid;
      var toPrincipal = p.amount - toInterest;
      if (toPrincipal > principal) toPrincipal = principal;
      interestPaid += toInterest;
      principal -= toPrincipal;
      principalRepaid += toPrincipal;
      totalPaid += p.amount;
      splits.add(PaymentSplit(p, _r2(toInterest), _r2(toPrincipal)));
    }

    if (principal > 0 && end.isAfter(last)) {
      accrued += interest(
        principal: principal,
        rate: loan.rate,
        monthly: loan.monthly,
        from: last,
        to: end,
      );
    }

    return LedgerSnapshot(
      principalOutstanding: _r2(principal),
      accrued: _r2(accrued),
      interestPaid: _r2(interestPaid),
      principalRepaid: _r2(principalRepaid),
      totalPaid: _r2(totalPaid),
      splits: splits,
    );
  }

  /// Days between two dates (kept here so screens only import one helper).
  static int days(DateTime from, DateTime to) => daysBetween(from, to);
}
