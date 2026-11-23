/// The design is a demo ledger "as of 01 Oct 2026".
/// Set [useDemoDate] to false to use the real date from the phone.
class AppClock {
  static bool useDemoDate = true;

  static DateTime today() {
    if (useDemoDate) return DateTime(2026, 10, 1);
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}
