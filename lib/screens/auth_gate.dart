import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import 'main_shell.dart';
import 'welcome_screen.dart';

/// First screen of the app. Logged in -> the app. Logged out -> Welcome.
/// Firebase remembers the login, so you stay signed in after closing the app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final ledger = context.read<LedgerProvider>();
        final user = snapshot.data;
        if (user == null) {
          ledger.stop();
          return const WelcomeScreen();
        }

        ledger.start(
          user.uid,
          displayName: user.displayName,
          email: user.email,
        );
        return const MainShell();
      },
    );
  }
}
