import 'package:flutter/material.dart';
import '../utils/app_nav.dart';
import 'analytics_screen.dart';
import 'contacts_screen.dart';
import 'dashboard_screen.dart';
import 'loans_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const List<Widget> _pages = [
    DashboardScreen(),
    LoansScreen(),
    ContactsScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mainTab,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(index: index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => mainTab.value = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz),
              label: 'Loans',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
