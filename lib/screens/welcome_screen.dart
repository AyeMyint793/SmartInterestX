import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _logoRow(),
              const SizedBox(height: 24),
              _heroCard(),
              const SizedBox(height: 28),
              const Text(
                'Every loan clear.\nEvery day calmer.',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Track money you lend and borrow, without the spreadsheets or guesswork.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 20),
              _feature(Icons.swap_horiz, 'All your loans in one ledger'),
              _feature(Icons.calculate_outlined, 'Simple interest, calculated for you'),
              _feature(Icons.notifications_none, 'Gentle reminders before dues'),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Get started',
                icon: Icons.arrow_forward,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
              ),
              const SizedBox(height: 12),
              SoftButton(
                label: 'I already have a ledger',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A record-keeping app. No money is moved here.',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoRow() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.percent, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Text(
          'SmartInterestX',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR MONEY, AT A GLANCE',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₹1,01,700',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.south_west, size: 16, color: AppColors.tealLight),
                    SizedBox(width: 6),
                    Text(
                      'To receive · all in one place',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.notifications_none, color: AppColors.teal),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A little reminder. A clearer day.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Know what is due, before it is due.',
                        style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textDark),
          const SizedBox(width: 14),
          Text(
            text,
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
