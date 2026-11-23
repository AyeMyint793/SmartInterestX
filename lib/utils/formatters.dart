const List<String> kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> kMonthLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// 101700 -> ₹1,01,700   (decimals only when needed)
String formatRupees(num value) {
  final negative = value < -0.004;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final decimals = parts[1] == '00' ? '' : '.${parts[1]}';
  final sign = negative ? '-' : '';
  return '$sign₹${_groupIndian(parts[0])}$decimals';
}

/// 170000 -> ₹1.70L
String formatLakh(num value) {
  if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(2)}L';
  return formatRupees(value);
}

String formatRate(double rate) {
  if (rate == rate.roundToDouble()) return rate.toStringAsFixed(0);
  return rate.toString();
}

/// 500.0 -> "500", 500.5 -> "500.50"  (for text fields and chart labels)
String plainNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) =>
    '${_two(d.day)} ${kMonthShort[d.month - 1]} ${d.year}';

String formatShortDate(DateTime d) =>
    '${_two(d.day)} ${kMonthShort[d.month - 1]}';

String formatTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:${_two(d.minute)} $suffix';
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Whole days from [from] to [to] (negative if [to] is earlier).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

String dueLabel(DateTime due, DateTime today) {
  final days = daysBetween(today, due);
  if (days == 0) return 'due today';
  if (days == 1) return 'due tomorrow';
  return 'due ${formatShortDate(due)}';
}
