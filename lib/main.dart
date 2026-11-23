import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/ledger_provider.dart';
import 'providers/security_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/loan_detail_screen.dart';
import 'screens/lock_screen.dart';
import 'services/notification_service.dart';
import 'utils/app_colors.dart';
import 'utils/app_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.init(
    onTap: (loanId) => navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loanId)),
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LedgerProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()..load()),
      ],
      child: const SmartInterestApp(),
    ),
  );
}

class SmartInterestApp extends StatelessWidget {
  const SmartInterestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SmartInterestX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal),
        scaffoldBackgroundColor: AppColors.background,
        snackBarTheme:
            const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.mint,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.teal
                  : AppColors.textGrey,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.teal
                  : AppColors.textGrey,
            ),
          ),
        ),
      ),
      builder: (context, child) => AppLockGate(child: child!),
      home: const AuthGate(),
    );
  }
}
