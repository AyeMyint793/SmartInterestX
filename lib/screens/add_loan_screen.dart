import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/loan_model.dart';
import '../providers/ledger_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/interest_calculator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import 'add_contact_screen.dart';

class AddLoanScreen extends StatefulWidget {
  final String? contactId;

  /// When set, the screen edits this loan instead of adding a new one.
  final String? editLoanId;

  const AddLoanScreen({super.key, this.contactId, this.editLoanId});

  static void open(BuildContext context, {String? contactId, String? editLoanId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLoanScreen(contactId: contactId, editLoanId: editLoanId),
      ),
    );
  }

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _notes = TextEditingController();

  int _type = 0; // 0 = given, 1 = taken
  bool _monthly = true;
  String? _contactId;
  late DateTime _start;
  DateTime? _due;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ledger = context.read<LedgerProvider>();
    _start = ledger.today;
    _contactId = widget.contactId;

    final editId = widget.editLoanId;
    if (editId != null) {
      final loan = ledger.loanById(editId)?.loan;
      if (loan != null) {
        _type = loan.isGiven ? 0 : 1;
        _contactId = loan.contactId;
        _principal.text = plainNumber(loan.principal);
        _rate.text = formatRate(loan.rate);
        _monthly = loan.monthly;
        _start = loan.start;
        _due = loan.due;
        _notes.text = loan.notes;
      }
    }
  }

  bool get _editing => widget.editLoanId != null;

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _principalValue => double.tryParse(_principal.text.trim()) ?? 0;
  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;

  Future<void> _pickContact() async {
    final ledger = context.read<LedgerProvider>();
    final contacts = ledger.contacts;
    final options = [
      for (final c in contacts) '${c.name} · ${c.typeLabel}',
      '+ Add a new contact',
    ];
    final selected = contacts.indexWhere((c) => c.id == _contactId);
    final choice = await showOptionSheet(
      context,
      title: 'Choose a contact',
      options: options,
      selected: selected < 0 ? null : selected,
    );
    if (choice == null || !mounted) return;
    if (choice == contacts.length) {
      final newId = await AddContactScreen.open(context);
      if (newId != null && mounted) setState(() => _contactId = newId);
    } else {
      setState(() => _contactId = contacts[choice].id);
    }
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      _start = d;
      if (_due != null && _due!.isBefore(d)) _due = null;
    });
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? _start,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = d);
  }

  void _save() {
    if (_contactId == null) {
      setState(() => _error = 'Choose a contact first.');
      return;
    }
    if (_principalValue <= 0) {
      setState(() => _error = 'Enter the principal amount.');
      return;
    }
    if (_rateValue <= 0) {
      setState(() => _error = 'Enter an interest rate above 0.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (_editing) {
      final ledger = context.read<LedgerProvider>();
      final existing = ledger.loanById(widget.editLoanId!)?.loan;
      if (existing != null) {
        ledger.updateLoan(Loan(
          number: existing.number,
          contactId: _contactId!,
          type: _type == 0 ? 'given' : 'taken',
          principal: _principalValue,
          rate: _rateValue,
          monthly: _monthly,
          start: _start,
          due: _due,
          notes: _notes.text.trim(),
        ));
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text('${existing.id} updated')),
        );
        return;
      }
    }
    final loan = context.read<LedgerProvider>().addLoan(
          contactId: _contactId!,
          type: _type == 0 ? 'given' : 'taken',
          principal: _principalValue,
          rate: _rateValue,
          monthly: _monthly,
          start: _start,
          due: _due,
          notes: _notes.text.trim(),
        );
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text('${loan.id} saved')));
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final contact = _contactId == null ? null : ledger.contactById(_contactId!);
    final given = _type == 0;

    return SubScreen(
      title: _editing ? 'Edit loan' : 'Add a loan',
      subtitle: _editing
          ? 'Changes recalculate the interest'
          : 'A new record, not a money transfer',
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
            label: _editing ? 'Save changes' : 'Save loan',
            onPressed: _save,
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        children: [
          SegmentTabs(
            options: const ['Given · you lent', 'Taken · you borrowed'],
            selected: _type,
            onChanged: (i) => setState(() => _type = i),
          ),
          const SizedBox(height: 20),
          PickerField(
            label: 'Contact',
            value: contact == null
                ? 'Select a contact'
                : '${contact.name} · ${contact.typeLabel}',
            isPlaceholder: contact == null,
            icon: Icons.keyboard_arrow_down,
            onTap: _pickContact,
            helper: 'Select a saved contact or add someone new.',
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Principal amount',
            controller: _principal,
            hint: '30,000',
            prefixText: '₹',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Simple interest rate (%)',
            controller: _rate,
            hint: '1.00',
            suffixText: '%',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            helper: 'Applied to principal only. No compound interest.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Rate frequency'),
          const SizedBox(height: 8),
          SegmentTabs(
            options: const ['Monthly', 'Yearly'],
            selected: _monthly ? 0 : 1,
            onChanged: (i) => setState(() => _monthly = i == 0),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PickerField(
                  label: 'Start date',
                  value: formatDate(_start),
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PickerField(
                  label: 'Due date · optional',
                  value: _due == null ? 'Not set' : formatDate(_due!),
                  isPlaceholder: _due == null,
                  icon: _due == null
                      ? Icons.calendar_today_outlined
                      : Icons.close,
                  onTap: _pickDue,
                  onIconTap:
                      _due == null ? _pickDue : () => setState(() => _due = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Notes · optional',
            controller: _notes,
            hint: 'Stock purchase for festive season',
          ),
          const SizedBox(height: 20),
          _preview(given),
          const SizedBox(height: 14),
          if (!_editing)
            const HintText('Draft only · not included in your dashboard yet.'),
        ],
      ),
    );
  }

  Widget _preview(bool given) {
    final due = _due;
    double interest = 0;
    String formula = 'Set a due date to preview the interest';
    if (due != null && _principalValue > 0 && _rateValue > 0) {
      interest = InterestCalculator.interest(
        principal: _principalValue,
        rate: _rateValue,
        monthly: _monthly,
        from: _start,
        to: due,
      );
      final period = InterestCalculator.periodLabel(_start, due, _monthly);
      formula =
          '${formatRupees(_principalValue)} × ${formatRate(_rateValue)}% × $period';
    } else if (due != null) {
      formula = 'Enter an amount and a rate to preview the interest';
    }
    final total = _principalValue + interest;

    return AppCard(
      color: AppColors.mint,
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Simple-interest preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Projected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  formula,
                  style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                ),
              ),
              Text(
                formatRupees(interest),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFC3DCD6)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total ${given ? 'receivable' : 'payable'} at due date',
                  style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                ),
              ),
              Text(
                formatRupees(total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const HintText(
            'Estimate with no payments. Monthly calculations use 30-day months; yearly uses 360 days. Part periods are prorated.',
          ),
        ],
      ),
    );
  }
}
