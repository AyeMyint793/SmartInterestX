import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds export and backup files and opens the phone's share sheet.
class ExportService {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 20261022_0930
  static String stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}_${_two(d.hour)}${_two(d.minute)}';

  static String _cell(Object value) {
    if (value is double) return value.toStringAsFixed(2);
    var s = value.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      s = '"' + s.replaceAll('"', '""') + '"';
    }
    return s;
  }

  /// Turns a table (header row + data rows) into CSV text.
  static String toCsv(List<List<Object>> rows) =>
      rows.map((r) => r.map(_cell).join(',')).join('\n') + '\n';

  static Future<String> _writeFile(
    String name,
    List<int> bytes, {
    bool permanent = false,
  }) async {
    final dir = permanent
        ? await getApplicationDocumentsDirectory()
        : await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> _share(String path, String mime, String text) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: mime)],
      text: text,
    );
  }

  /// CSV with a byte-order mark so Excel reads names correctly.
  static Future<void> shareCsv(List<List<Object>> rows, DateTime now) async {
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(toCsv(rows))];
    final path = await _writeFile('smartinterestx_loans_${stamp(now)}.csv', bytes);
    await _share(path, 'text/csv', 'SmartInterestX loans');
  }

  static xl.CellValue _value(Object v) {
    if (v is int) return xl.IntCellValue(v);
    if (v is double) return xl.DoubleCellValue(v);
    return xl.TextCellValue(v.toString());
  }

  static void _fillSheet(xl.Sheet sheet, List<List<Object>> rows) {
    for (final row in rows) {
      sheet.appendRow(row.map(_value).toList());
    }
  }

  /// Excel file with a Loans sheet and a Payments sheet.
  static Future<void> shareExcel(
    List<List<Object>> loans,
    List<List<Object>> payments,
    DateTime now,
  ) async {
    final book = xl.Excel.createExcel();
    _fillSheet(book['Loans'], loans);
    _fillSheet(book['Payments'], payments);
    book.delete('Sheet1');
    final bytes = book.save();
    if (bytes == null) throw Exception('Could not create the Excel file.');
    final path = await _writeFile('smartinterestx_loans_${stamp(now)}.xlsx', bytes);
    await _share(
      path,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'SmartInterestX loans',
    );
  }

  /// Saves the backup file on the phone, then opens the share sheet so you
  /// can keep a copy in Files, Drive, WhatsApp, email ...
  static Future<void> saveAndShareBackup(String json, DateTime now) async {
    final path = await _writeFile(
      'smartinterestx_backup_${stamp(now)}.json',
      utf8.encode(json),
      permanent: true,
    );
    await _share(path, 'application/json', 'SmartInterestX backup');
  }
}
