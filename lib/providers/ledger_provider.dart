import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/contact_model.dart';
import '../models/loan_model.dart';
import '../models/payment_model.dart';
import '../services/notification_service.dart';
import '../utils/app_clock.dart';
import '../utils/formatters.dart';
import '../utils/interest_calculator.dart';

/// A loan together with its contact, payments and calculated balances.
class LoanView {
  final Loan loan;
  final Contact? contact;
  final List<Payment> payments;
  final LedgerSnapshot now; // balances as of today
  final LedgerSnapshot projected; // balances at the due date, no more payments
  final String status; // Active, Partial, Overdue, Settled
  final int overdueDays;

  const LoanView({
    required this.loan,
    required this.contact,
    required this.payments,
    required this.now,
    required this.projected,
    required this.status,
    required this.overdueDays,
  });

  String get id => loan.id;
  String get name => contact?.name ?? 'Unknown contact';
  String get initials => contact?.initials ?? '?';
  bool get isGiven => loan.isGiven;
  bool get isSettled => status == 'Settled';
  double get balance => now.balance;

  DateTime? get lastPaymentDate {
    if (payments.isEmpty) return null;
    return payments.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

/// One payment split into interest and principal, with its loan.
class SplitRow {
  final LoanView view;
  final PaymentSplit split;

  const SplitRow(this.view, this.split);
}

/// Holds the whole ledger. Data lives in Cloud Firestore under
/// users/{uid}/contacts, users/{uid}/loans, users/{uid}/payments and the
/// settings sit on the users/{uid} document itself.
class LedgerProvider extends ChangeNotifier {
  List<Contact> _contacts = [];
  List<Loan> _loans = [];
  List<Payment> _payments = [];

  String? _uid;
  Timer? _reminderTimer;
  final List<StreamSubscription<dynamic>> _subs = [];
  final Set<String> _got = {};

  /// Last sync problem (for example, rules not published). Null when fine.
  String? error;

  // ---- Settings (saved on the user document) ----
  String userName = 'there';
  bool reminderEnabled = true;
  int reminderDays = 3;
  bool overdueAlerts = true;
  bool monthlySummary = true;
  bool pinEnabled = false;
  bool biometricEnabled = false;
  String autoLock = 'When you leave the app';
  DateTime? lastBackup;

  DateTime get today => AppClock.today();

  /// True once contacts, loans and payments have been read from Firestore.
  bool get ready =>
      _got.contains('contacts') &&
      _got.contains('loans') &&
      _got.contains('payments');

  // ---- Firestore paths ----
  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _userDoc.collection(name);

  // ---- Start / stop (called by AuthGate) ----

  /// Starts listening to this user's data. Safe to call many times.
  void start(String uid, {String? displayName, String? email}) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    NotificationService.requestPermission();

    final name = (displayName ?? '').trim();
    final fromEmail = (email ?? '').split('@').first;
    userName = name.isNotEmpty ? name : (fromEmail.isNotEmpty ? fromEmail : 'there');

    _subs.add(_col('contacts').snapshots().listen((snap) {
      _contacts = snap.docs.map((d) => Contact.fromMap(d.data())).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _loaded('contacts');
    }, onError: _onError));

    _subs.add(_col('loans').snapshots().listen((snap) {
      _loans = snap.docs.map((d) => Loan.fromMap(d.data())).toList();
      _loaded('loans');
    }, onError: _onError));

    _subs.add(_col('payments').snapshots().listen((snap) {
      _payments = snap.docs.map((d) => Payment.fromMap(d.data())).toList();
      _loaded('payments');
    }, onError: _onError));

    _subs.add(_userDoc.snapshots().listen(_applySettings, onError: _onError));
  }

  /// Stops listening and forgets the data (on log out). Does not notify,
  /// because it can run while the screen is being built.
  void stop() {
    _reminderTimer?.cancel();
    if (_uid != null) NotificationService.cancelAll();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _got.clear();
    _uid = null;
    _contacts = [];
    _loans = [];
    _payments = [];
    error = null;
    userName = 'there';
    reminderEnabled = true;
    reminderDays = 3;
    overdueAlerts = true;
    monthlySummary = true;
    pinEnabled = false;
    biometricEnabled = false;
    autoLock = 'When you leave the app';
    lastBackup = null;
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ---- Reminders: rebuilt a moment after any data or settings change ----
  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleReminderSync();
  }

  void _scheduleReminderSync() {
    if (_uid == null || !ready) return;
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(milliseconds: 800), _syncReminders);
  }

  void _syncReminders() {
    final now = DateTime.now();
    final items = <ReminderItem>[];
    for (final v in loans) {
      final due = v.loan.due;
      if (v.isSettled || due == null) continue;
      items.add(ReminderItem(
        number: v.loan.number,
        loanId: v.id,
        name: v.name,
        isGiven: v.isGiven,
        amount: v.projected.balance,
        due: due,
      ));
    }

    // Monthly summary: sent on the 1st of next month, covering this month.
    final rows = splitRows(year: now.year, month: now.month);
    final earned = sumInterest(rows, given: true);
    final paid = sumInterest(rows, given: false);
    final net = earned - paid;

    NotificationService.sync(
      items: items,
      remindersOn: reminderEnabled,
      daysBefore: reminderDays,
      overdueOn: overdueAlerts,
      summaryOn: monthlySummary,
      nextSummaryAt: DateTime(now.year, now.month + 1, 1, 8),
      summaryTitle: 'Your ${kMonthLong[now.month - 1]} summary',
      summaryBody:
          '${formatRupees(earned)} interest earned and ${formatRupees(paid)} interest paid. '
          'Net ${net >= 0 ? 'received' : 'paid'}: ${formatRupees(net.abs())}.',
    );
  }

  void _loaded(String what) {
    _got.add(what);
    error = null;
    notifyListeners();
  }

  void _onError(Object e) {
    error = e.toString();
    notifyListeners();
  }

  void _write(Future<void> future) {
    future.catchError((Object e) {
      _onError(e);
    });
  }

  void _applySettings(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d != null) {
      userName = (d['name'] as String?) ?? userName;
      reminderEnabled = (d['reminderEnabled'] as bool?) ?? reminderEnabled;
      reminderDays = (d['reminderDays'] as num?)?.toInt() ?? reminderDays;
      overdueAlerts = (d['overdueAlerts'] as bool?) ?? overdueAlerts;
      monthlySummary = (d['monthlySummary'] as bool?) ?? monthlySummary;
      pinEnabled = (d['pinEnabled'] as bool?) ?? pinEnabled;
      biometricEnabled = (d['biometricEnabled'] as bool?) ?? biometricEnabled;
      autoLock = (d['autoLock'] as String?) ?? autoLock;
      final backup = d['lastBackup'] as String?;
      lastBackup = backup == null ? null : DateTime.tryParse(backup);
    }
    notifyListeners();
  }

  void _saveSettings() {
    if (_uid == null) return;
    _write(_userDoc.set({
      'name': userName,
      'reminderEnabled': reminderEnabled,
      'reminderDays': reminderDays,
      'overdueAlerts': overdueAlerts,
      'monthlySummary': monthlySummary,
      'pinEnabled': pinEnabled,
      'biometricEnabled': biometricEnabled,
      'autoLock': autoLock,
      'lastBackup': lastBackup?.toIso8601String(),
    }, SetOptions(merge: true)));
  }

  /// Change any public setting, refresh the screens and save it:
  /// `ledger.change(() => ledger.pinEnabled = true);`
  void change(VoidCallback update) {
    update();
    notifyListeners();
    _saveSettings();
  }

  // ---- Reading data ----
  List<Contact> get contacts => List.unmodifiable(_contacts);

  Contact? contactById(String id) {
    for (final c in _contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  LoanView _view(Loan l) {
    final pays = _payments.where((p) => p.loanId == l.id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final now = InterestCalculator.replay(l, pays, today);
    final due = l.due;
    final projected = (due != null && due.isAfter(today))
        ? InterestCalculator.replay(l, pays, due)
        : now;

    var status = 'Active';
    var overdue = 0;
    if (now.isSettled) {
      status = 'Settled';
    } else if (due != null && due.isBefore(today)) {
      status = 'Overdue';
      overdue = daysBetween(due, today);
    } else if (pays.isNotEmpty) {
      status = 'Partial';
    }

    return LoanView(
      loan: l,
      contact: contactById(l.contactId),
      payments: pays,
      now: now,
      projected: projected,
      status: status,
      overdueDays: overdue,
    );
  }

  /// Newest loan first.
  List<LoanView> get loans {
    final list = _loans.map(_view).toList()
      ..sort((a, b) => b.loan.number.compareTo(a.loan.number));
    return list;
  }

  LoanView? loanById(String id) {
    for (final l in _loans) {
      if (l.id == id) return _view(l);
    }
    return null;
  }

  List<LoanView> loansOf(String contactId) =>
      loans.where((v) => v.loan.contactId == contactId).toList();

  int get nextLoanNumber => _loans.isEmpty
      ? 1
      : _loans.map((l) => l.number).reduce((a, b) => a > b ? a : b) + 1;

  // ---- Totals ----
  double get receivables =>
      loans.where((v) => v.isGiven).fold<double>(0, (s, v) => s + v.balance);

  double get payables =>
      loans.where((v) => !v.isGiven).fold<double>(0, (s, v) => s + v.balance);

  List<SplitRow> splitRows({int? year, int? month, String? contactId}) {
    final rows = <SplitRow>[];
    for (final v in loans) {
      if (contactId != null && v.loan.contactId != contactId) continue;
      for (final s in v.now.splits) {
        final d = s.payment.date;
        if (year != null && d.year != year) continue;
        if (month != null && d.month != month) continue;
        rows.add(SplitRow(v, s));
      }
    }
    return rows;
  }

  /// Interest received (given loans) or paid (taken loans) in [rows].
  double sumInterest(List<SplitRow> rows, {required bool given}) => rows
      .where((r) => r.view.isGiven == given)
      .fold<double>(0, (s, r) => s + r.split.interest);

  double get interestEarned => sumInterest(splitRows(), given: true);
  double get interestPaid => sumInterest(splitRows(), given: false);

  int get paymentCount => _payments.length;

  // ---- Changing data (saved to Firestore) ----
  Contact addContact({
    required String name,
    required String mobile,
    String email = '',
    required String type,
  }) {
    final doc = _col('contacts').doc();
    final c = Contact(
      id: doc.id,
      name: name,
      mobile: mobile,
      email: email,
      type: type,
    );
    _contacts = [..._contacts, c];
    notifyListeners();
    _write(doc.set(c.toMap()));
    return c;
  }

  Loan addLoan({
    required String contactId,
    required String type,
    required double principal,
    required double rate,
    required bool monthly,
    required DateTime start,
    DateTime? due,
    String notes = '',
  }) {
    final loan = Loan(
      number: nextLoanNumber,
      contactId: contactId,
      type: type,
      principal: principal,
      rate: rate,
      monthly: monthly,
      start: start,
      due: due,
      notes: notes,
    );
    _loans = [..._loans, loan];
    notifyListeners();
    _write(_col('loans').doc(loan.id).set(loan.toMap()));
    return loan;
  }

  void addPayment({
    required String loanId,
    required DateTime date,
    required double amount,
    required String mode,
    String? proofName,
    String? proofPath,
    String? proofData,
  }) {
    final doc = _col('payments').doc();
    final payment = Payment(
      id: doc.id,
      loanId: loanId,
      date: date,
      amount: amount,
      mode: mode,
      proofName: proofName,
      proofPath: proofPath,
      proofData: proofData,
    );
    _payments = [..._payments, payment];
    notifyListeners();
    _write(doc.set(payment.toMap()));
  }

  void updateLoan(Loan loan) {
    _loans = _loans.map((l) => l.id == loan.id ? loan : l).toList();
    notifyListeners();
    _write(_col('loans').doc(loan.id).set(loan.toMap()));
  }

  void updatePayment(Payment payment) {
    _payments = _payments.map((p) => p.id == payment.id ? payment : p).toList();
    notifyListeners();
    _write(_col('payments').doc(payment.id).set(payment.toMap()));
  }

  void deletePayment(String paymentId) {
    _payments = _payments.where((p) => p.id != paymentId).toList();
    notifyListeners();
    _write(_col('payments').doc(paymentId).delete());
  }

  void deleteLoan(String loanId) {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_col('loans').doc(loanId));
    for (final p in _payments.where((p) => p.loanId == loanId)) {
      batch.delete(_col('payments').doc(p.id));
    }
    _loans = _loans.where((l) => l.id != loanId).toList();
    _payments = _payments.where((p) => p.loanId != loanId).toList();
    notifyListeners();
    _write(batch.commit());
  }

  void markBackupDone() {
    lastBackup = DateTime.now();
    notifyListeners();
    _saveSettings();
  }

  // ---- Sample ledger (the one from the design) ----
  static const List<Contact> _sampleContacts = [
    Contact(id: 'c1', name: 'Rahul Sharma', mobile: '+91 98765 43210', type: 'borrower'),
    Contact(id: 'c2', name: 'Meera Shah', mobile: '+91 98234 56789', type: 'borrower'),
    Contact(id: 'c3', name: 'Anil Patel', mobile: '+91 98901 23456', type: 'borrower'),
    Contact(id: 'c4', name: 'Kavita Rao', mobile: '+91 98123 45678', type: 'lender'),
  ];

  static final List<Loan> _sampleLoans = [
    Loan(number: 99, contactId: 'c4', type: 'taken', principal: 20000, rate: 1, monthly: true, start: DateTime(2026, 5, 1), due: DateTime(2026, 8, 1)),
    Loan(number: 100, contactId: 'c2', type: 'given', principal: 10000, rate: 1, monthly: true, start: DateTime(2026, 6, 1), due: DateTime(2026, 8, 1)),
    Loan(number: 101, contactId: 'c4', type: 'taken', principal: 40000, rate: 1, monthly: true, start: DateTime(2026, 8, 1), due: DateTime(2026, 11, 1)),
    Loan(number: 102, contactId: 'c3', type: 'given', principal: 20000, rate: 1, monthly: true, start: DateTime(2026, 7, 1), due: DateTime(2026, 9, 1)),
    Loan(number: 103, contactId: 'c2', type: 'given', principal: 30000, rate: 1, monthly: true, start: DateTime(2026, 8, 1), due: DateTime(2026, 10, 1)),
    Loan(number: 104, contactId: 'c1', type: 'given', principal: 50000, rate: 1, monthly: true, start: DateTime(2026, 7, 1), due: DateTime(2026, 11, 1), notes: 'Working capital for shop renovation.'),
  ];

  static final List<Payment> _samplePayments = [
    Payment(id: 'p1', loanId: 'SIX-104', date: DateTime(2026, 8, 1), amount: 500, mode: 'Bank transfer', proofName: 'rahul_bank_01aug.png'),
    Payment(id: 'p2', loanId: 'SIX-104', date: DateTime(2026, 9, 1), amount: 500, mode: 'UPI', proofName: 'rahul_upi_01sep.png'),
    Payment(id: 'p3', loanId: 'SIX-100', date: DateTime(2026, 8, 1), amount: 10200, mode: 'Cash'),
    Payment(id: 'p4', loanId: 'SIX-099', date: DateTime(2026, 8, 1), amount: 20600, mode: 'Bank transfer'),
    Payment(id: 'p5', loanId: 'SIX-101', date: DateTime(2026, 9, 1), amount: 400, mode: 'UPI'),
  ];

  /// Writes the design's sample ledger into this user's Firestore data.
  Future<void> loadSampleData() async {
    if (_uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final c in _sampleContacts) {
      batch.set(_col('contacts').doc(c.id), c.toMap());
    }
    for (final l in _sampleLoans) {
      batch.set(_col('loans').doc(l.id), l.toMap());
    }
    for (final p in _samplePayments) {
      batch.set(_col('payments').doc(p.id), p.toMap());
    }
    try {
      await batch.commit();
    } catch (e) {
      _onError(e);
    }
  }

  // ---- Export & backup ----
  String exportCsv(List<LoanView> views) {
    String esc(String s) => '"' + s.replaceAll('"', '""') + '"';
    final b = StringBuffer(
        'Loan ID,Contact,Type,Principal,Rate (%),Frequency,Start date,Due date,'
        'Interest accrued,Total paid,Balance,Status\n');
    for (final v in views) {
      final l = v.loan;
      b.writeln([
        esc(l.id),
        esc(v.name),
        l.typeLabel,
        l.principal.toStringAsFixed(2),
        formatRate(l.rate),
        l.monthly ? 'Monthly' : 'Yearly',
        formatDate(l.start),
        l.due == null ? '' : formatDate(l.due!),
        v.now.accrued.toStringAsFixed(2),
        v.now.totalPaid.toStringAsFixed(2),
        v.balance.toStringAsFixed(2),
        v.status,
      ].join(','));
    }
    return b.toString();
  }

  /// Header + one row per loan (used by the CSV and Excel export).
  List<List<Object>> loanTable(List<LoanView> views) {
    final rows = <List<Object>>[
      [
        'Loan ID', 'Contact', 'Type', 'Principal', 'Rate (%)', 'Frequency',
        'Start date', 'Due date', 'Interest accrued', 'Total paid', 'Balance',
        'Status',
      ],
    ];
    for (final v in views) {
      final l = v.loan;
      rows.add([
        l.id,
        v.name,
        l.typeLabel,
        l.principal,
        l.rate,
        l.monthly ? 'Monthly' : 'Yearly',
        formatDate(l.start),
        l.due == null ? '' : formatDate(l.due!),
        v.now.accrued,
        v.now.totalPaid,
        v.balance,
        v.status,
      ]);
    }
    return rows;
  }

  /// Header + one row per payment of the given loans.
  List<List<Object>> paymentTable(List<LoanView> views) {
    final rows = <List<Object>>[
      [
        'Loan ID', 'Contact', 'Date', 'Amount', 'Mode', 'Interest part',
        'Principal part', 'Proof',
      ],
    ];
    for (final v in views) {
      for (final s in v.now.splits) {
        rows.add([
          v.id,
          v.name,
          formatDate(s.payment.date),
          s.payment.amount,
          s.payment.mode,
          s.interest,
          s.principal,
          s.payment.proofName ?? '',
        ]);
      }
    }
    return rows;
  }

  /// Replaces the whole ledger with the contents of a backup file.
  /// Returns an error message, or null when it worked.
  Future<String?> restoreFromBackup(String text) async {
    if (_uid == null) return 'Please log in first.';

    List<Contact> newContacts;
    List<Loan> newLoans;
    List<Payment> newPayments;
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      newContacts = (data['contacts'] as List)
          .map((e) => Contact.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      newLoans = (data['loans'] as List)
          .map((e) => Loan.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      newPayments = (data['payments'] as List)
          .map((e) => Payment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return 'This file is not a SmartInterestX backup.';
    }

    final writes = <void Function(WriteBatch)>[];
    for (final c in _contacts) {
      writes.add((b) => b.delete(_col('contacts').doc(c.id)));
    }
    for (final l in _loans) {
      writes.add((b) => b.delete(_col('loans').doc(l.id)));
    }
    for (final p in _payments) {
      writes.add((b) => b.delete(_col('payments').doc(p.id)));
    }
    for (final c in newContacts) {
      writes.add((b) => b.set(_col('contacts').doc(c.id), c.toMap()));
    }
    for (final l in newLoans) {
      writes.add((b) => b.set(_col('loans').doc(l.id), l.toMap()));
    }
    for (final p in newPayments) {
      writes.add((b) => b.set(_col('payments').doc(p.id), p.toMap()));
    }

    try {
      for (var i = 0; i < writes.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final w in writes.skip(i).take(400)) {
          w(batch);
        }
        await batch.commit();
      }
    } catch (e) {
      return 'Restore failed: $e';
    }
    return null;
  }

  String backupJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'createdAt': DateTime.now().toIso8601String(),
      'contacts': _contacts.map((c) => c.toMap()).toList(),
      'loans': _loans.map((l) => l.toMap()).toList(),
      'payments': _payments.map((p) => p.toMap()).toList(),
    });
  }
}
