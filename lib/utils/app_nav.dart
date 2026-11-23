import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Index of the selected bottom-bar tab (0 Home, 1 Loans, 2 Contacts,
/// 3 Analytics, 4 Settings). Any screen can change tab with `mainTab.value = 1`.
final ValueNotifier<int> mainTab = ValueNotifier<int>(0);

/// Lets code outside a screen (like a notification tap) open screens.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
