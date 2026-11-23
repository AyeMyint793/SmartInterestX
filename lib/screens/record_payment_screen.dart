import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/payment_model.dart';
import '../providers/ledger_provider.dart';
import '../providers/security_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/interest_calculator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String loanId;

  /// When set, the screen edits this payment instead of adding a new one.
  final String? paymentId;

  const RecordPaymentScreen({super.key, required this.loanId, this.paymentId});

  static void open(BuildContext context, String loanId, {String? paymentId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPaymentScreen(loanId: loanId, paymentId: paymentId),
      ),
    );
  }

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  static const List<String> _modes = ['UPI', 'Bank transfer', 'Cash', 'Other'];

  final _amount = TextEditingController();
  late DateTime _date;
  int _mode = 0;
  bool _settle = false;
  String? _proofName;
  String? _proofPath;
  String? _proofData;
  int? _proofBytes;
  String? _error;

  bool get _editing => widget.paymentId != null;

  @override
  void initState() {
    super.initState();
    final ledger = context.read<LedgerProvider>();
    _date = ledger.today;
    if (_editing) {
      final loan = ledger.loanById(widget.loanId);
      if (loan != null) {
        for (final p in loan.payments) {
          if (p.id == widget.paymentId) {
            _amount.text = plainNumber(p.amount);
            _date = p.date;
            final m = _modes.indexOf(p.mode);
            _mode = m < 0 ? 0 : m;
            _proofName = p.proofName;
            _proofPath = p.proofPath;
            _proofData = p.proofData;
          }
        }
      }
    }
  }

  /// The loan's payments without the one being edited.
  List<Payment> _others(LoanView v) =>
      v.payments.where((p) => p.id != widget.paymentId).toList();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  LedgerSnapshot _before(LoanView v, DateTime date) =>
      InterestCalculator.replay(v.loan, _others(v), date);

  double _amountValue(LoanView v) =>
      _settle ? _before(v, _date).balance : (double.tryParse(_amount.text.trim()) ?? 0);

  Future<void> _pickDate(LoanView v) async {
    final today = context.read<LedgerProvider>().today;
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(v.loan.start) ? v.loan.start : _date,
      firstDate: v.loan.start,
      lastDate: today.isAfter(_date) ? today : _date,
    );
    if (d == null) return;
    setState(() {
      _date = d;
      if (_settle) _amount.text = plainNumber(_before(v, d).balance);
    });
  }

  Future<void> _pickProof() async {
    // The photo is shrunk so it fits inside a Firestore document.
    final file = await context.read<SecurityProvider>().guard(
          () => ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 1280,
            maxHeight: 1280,
            imageQuality: 70,
          ),
        );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final encoded = base64Encode(bytes);
    if (!mounted) return;
    if (encoded.length > 800000) {
      showMessage(context, 'That image is too large. Choose a smaller one.');
      return;
    }
    setState(() {
      _proofName = file.name;
      _proofPath = file.path;
      _proofData = encoded;
      _proofBytes = bytes.length;
    });
  }

  void _save(LoanView v) {
    final amount = _amountValue(v);
    final balance = _before(v, _date).balance;
    if (amount <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }
    if (amount > balance + 0.01) {
      setState(() => _error = 'That is more than the ${formatRupees(balance)} balance on this date.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final ledger = context.read<LedgerProvider>();
    if (_editing) {
      ledger.updatePayment(Payment(
        id: widget.paymentId!,
        loanId: v.id,
        date: _date,
        amount: amount,
        mode: _modes[_mode],
        proofName: _proofName,
        proofPath: _proofPath,
        proofData: _proofData,
      ));
    } else {
      ledger.addPayment(
        loanId: v.id,
        date: _date,
        amount: amount,
        mode: _modes[_mode],
        proofName: _proofName,
        proofPath: _proofPath,
        proofData: _proofData,
      );
    }
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(_editing ? 'Payment updated' : 'Payment record saved'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final v = ledger.loanById(widget.loanId);
    if (v == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('Loan not found'))),
      );
    }

    final received = v.isGiven;
    final before = _before(v, _date);
    final amount = _amountValue(v);

    // Preview: add the new payment and replay the loan on the payment date.
    var interestCovered = 0.0;
    var principalRepaid = 0.0;
    var remaining = before.balance;
    var principalLeft = before.principalOutstanding;
    var willSettle = false;
    if (amount > 0) {
      final preview = Payment(
        id: 'preview',
        loanId: v.id,
        date: _date,
        amount: amount,
        mode: _modes[_mode],
      );
      final after = InterestCalculator.replay(v.loan, [..._others(v), preview], _date);
      for (final s in after.splits) {
        if (s.payment.id == 'preview') {
          interestCovered = s.interest;
          principalRepaid = s.principal;
        }
      }
      remaining = after.balance;
      principalLeft = after.principalOutstanding;
      willSettle = after.isSettled;
    }

    return SubScreen(
      title: _editing ? 'Edit payment' : 'Record payment',
      subtitle: '${v.name} · ${v.id} · ${v.loan.typeLabel}',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.red),
              ),
            ),
          PrimaryButton(
            label: _editing ? 'Save changes' : 'Save payment record',
            onPressed: () => _save(v),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        children: [
          // Balance before this payment
          AppCard(
            color: AppColors.mint,
            radius: 24,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${received ? 'RECEIVABLE' : 'PAYABLE'} BEFORE THIS PAYMENT',
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  formatRupees(before.balance),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'As of ${formatDate(_date)} · ${formatRupees(before.unpaidInterest)} is unpaid interest',
                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: received ? 'Amount received' : 'Amount paid',
            controller: _amount,
            hint: '10,000',
            prefixText: '₹',
            readOnly: _settle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          PickerField(
            label: 'Payment date',
            value: formatDate(_date),
            icon: Icons.calendar_today_outlined,
            onTap: () => _pickDate(v),
          ),
          const SizedBox(height: 20),
          const FieldLabel('How was it paid?'),
          const SizedBox(height: 8),
          SegmentTabs(
            options: const ['UPI', 'Bank transfer'],
            selected: _mode < 2 ? _mode : -1,
            onChanged: (i) => setState(() => _mode = i),
          ),
          const SizedBox(height: 10),
          SegmentTabs(
            options: const ['Cash', 'Other'],
            selected: _mode >= 2 ? _mode - 2 : -1,
            onChanged: (i) => setState(() => _mode = i + 2),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Screenshot or receipt · optional'),
          const SizedBox(height: 8),
          _proofBox(),
          const SizedBox(height: 20),
          const FieldLabel('Payment treatment'),
          const SizedBox(height: 8),
          SegmentTabs(
            options: const ['Partial payment', 'Fully settled'],
            selected: _settle ? 1 : 0,
            onChanged: (i) => setState(() {
              _settle = i == 1;
              if (_settle) _amount.text = plainNumber(before.balance);
            }),
          ),
          const SizedBox(height: 8),
          HintText(
            'To settle today, record the full ${formatRupees(before.balance)} balance.',
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Balance preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                KeyValueRow('Interest covered', formatRupees(interestCovered)),
                KeyValueRow('Principal repaid', formatRupees(principalRepaid)),
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 4),
                KeyValueRow(
                  'Remaining after saving',
                  formatRupees(remaining),
                  valueColor: AppColors.teal,
                ),
                const SizedBox(height: 8),
                willSettle
                    ? const Pill(
                        'Loan will be settled',
                        background: AppColors.mint,
                        foreground: AppColors.teal,
                      )
                    : const Pill(
                        'Loan stays partially paid',
                        background: AppColors.amberBg,
                        foreground: AppColors.amberText,
                      ),
                const SizedBox(height: 12),
                HintText(
                  willSettle
                      ? 'No further interest will accrue.'
                      : 'Future simple interest applies to ${formatRupees(principalLeft)} principal.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const HintText(
            'Only record a payment already made outside the app. This does not send or collect money.',
          ),
        ],
      ),
    );
  }

  Widget _proofBox() {
    if (_proofName == null) {
      return AppCard(
        onTap: _pickProof,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image_outlined, color: AppColors.teal),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attach a screenshot or receipt',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tap to choose from your gallery',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final size = _proofBytes == null ? '' : '${formatBytes(_proofBytes!)} · ';
    final sizeText = '${size}Ready to attach';

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.teal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _proofName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sizeText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _proofName = null;
                  _proofPath = null;
                  _proofData = null;
                  _proofBytes = null;
                }),
                icon: const Icon(Icons.close, color: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickProof,
            child: const Text(
              'Replace screenshot or receipt',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
