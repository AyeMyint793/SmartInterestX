import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  /// Opens the form. Returns the new contact's id when saved.
  static Future<String?> open(BuildContext context) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AddContactScreen()),
    );
  }

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  int _tag = 0; // 0 borrower, 1 lender
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final mobile = _mobile.text.trim();
    final email = _email.text.trim();
    final digitCount = mobile.replaceAll(RegExp(r'[^0-9]'), '').length;

    if (name.isEmpty) {
      setState(() => _error = 'Enter the full name.');
      return;
    }
    if (digitCount < 7) {
      setState(() => _error = 'Enter a valid mobile number.');
      return;
    }
    if (email.isNotEmpty && (!email.contains('@') || !email.contains('.'))) {
      setState(() => _error = 'That email address does not look right.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final contact = context.read<LedgerProvider>().addContact(
      name: name,
      mobile: mobile,
      email: email,
      type: _tag == 0 ? 'borrower' : 'lender',
    );
    Navigator.pop(context, contact.id);
    messenger.showSnackBar(SnackBar(content: Text('${contact.name} saved')));
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Add a contact',
      subtitle: 'Keep people and their loans connected',
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
          PrimaryButton(label: 'Save contact', onPressed: _save),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        children: [
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt,
                size: 40,
                color: AppColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'New contact · not yet saved',
            style: TextStyle(fontSize: 14, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Full name',
            controller: _name,
            hint: 'Priya Desai',
            suffixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Mobile number',
            controller: _mobile,
            hint: '+91 98712 34560',
            keyboardType: TextInputType.phone,
            suffixIcon: Icons.phone_outlined,
            helper: 'Include the country code for easy reference.',
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Email address · optional',
            controller: _email,
            hint: 'priya.desai@example.com',
            keyboardType: TextInputType.emailAddress,
            suffixIcon: Icons.mail_outline,
          ),
          const SizedBox(height: 20),
          const FieldLabel('Contact tag'),
          const SizedBox(height: 8),
          SegmentTabs(
            options: const ['Borrower', 'Lender'],
            selected: _tag,
            onChanged: (i) => setState(() => _tag = i),
          ),
          const SizedBox(height: 8),
          const HintText(
            'Borrower: someone you lend to.\nLender: someone you borrow from.',
          ),
          const SizedBox(height: 20),
          const AppCard(
            color: AppColors.mint,
            radius: 20,
            padding: EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.link, color: AppColors.teal),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'One contact, multiple loans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Link new loans to this contact. Their history and balances stay together.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const HintText(
            'Contact details are for your records. Saving does not send an invitation or message.',
          ),
        ],
      ),
    );
  }
}
