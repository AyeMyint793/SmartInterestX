import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/formatters.dart';

/// One loan that may need reminders.
class ReminderItem {
  final int number;
  final String loanId;
  final String name;
  final bool isGiven;
  final double amount; // projected balance on the due date
  final DateTime due;

  const ReminderItem({
    required this.number,
    required this.loanId,
    required this.name,
    required this.isGiven,
    required this.amount,
    required this.due,
  });
}

/// Schedules local notifications on the phone (no server needed).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'due_reminders',
      'Due date reminders',
      channelDescription: 'Reminders before your loans are due',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Call once when the app starts. [onTap] gets the loan id from the notification.
  static Future<void> init({required void Function(String loanId) onTap}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _ready = true;
  }

  /// Asks for the Android 13+ notification permission (shows once).
  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Removes every scheduled reminder (used on log out).
  static Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Shows a notification right now (used for the test button).
  static Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    await _plugin.show(0, title, body, _details, payload: payload);
  }

  static Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when,
    String? payload,
  ) async {
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.UTC), // same moment, expressed in UTC
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static DateTime _at(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);

  /// Cancels everything and schedules the reminders again.
  /// Safe to call often. Never throws.
  static Future<void> sync({
    required List<ReminderItem> items,
    required bool remindersOn,
    required int daysBefore,
    required bool overdueOn,
    required bool summaryOn,
    required DateTime nextSummaryAt,
    required String summaryTitle,
    required String summaryBody,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();

      for (final it in items) {
        final verb = it.isGiven ? 'to receive' : 'to pay';
        final amount = formatRupees(it.amount);
        final dueText = formatShortDate(it.due);
        final base = it.number * 10;

        if (remindersOn) {
          if (daysBefore > 0) {
            await _schedule(
              base + 1,
              '${it.name} · due in $daysBefore ${daysBefore == 1 ? 'day' : 'days'}',
              '$amount $verb on $dueText (${it.loanId}).',
              _at(it.due.subtract(Duration(days: daysBefore)), 9),
              it.loanId,
            );
          }
          await _schedule(
            base + 2,
            '${it.name} is due today',
            '$amount $verb (${it.loanId}). Open the loan to review it.',
            _at(it.due, 9),
            it.loanId,
          );
        }

        if (overdueOn) {
          // One alert a day for the first 7 days after the due date.
          for (var d = 1; d <= 7; d++) {
            await _schedule(
              base + 2 + d,
              '${it.name} is $d ${d == 1 ? 'day' : 'days'} overdue',
              '$amount $verb since $dueText (${it.loanId}).',
              _at(it.due.add(Duration(days: d)), 9),
              it.loanId,
            );
          }
        }
      }

      if (summaryOn) {
        await _schedule(1, summaryTitle, summaryBody, nextSummaryAt, null);
      }
    } catch (_) {
      // Reminders are a convenience. Never crash the app because of them.
    }
  }
}
