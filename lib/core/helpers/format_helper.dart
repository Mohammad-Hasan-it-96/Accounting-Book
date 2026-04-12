import 'package:intl/intl.dart';

/// مساعد لتنسيق التواريخ والأرقام
class FormatHelper {
  /// تحويل النص إلى تاريخ بطريقة آمنة
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// تنسيق التاريخ للعرض
  static String formatDate(String? dateStr) {
    final dt = parseDate(dateStr);
    if (dt == null) return dateStr ?? '';
    return formatDateFromDateTime(dt);
  }

  /// تنسيق تاريخ جاهز للعرض في الواجهة
  static String formatDateFromDateTime(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  /// تنسيق تاريخ للتخزين في قاعدة البيانات
  static String formatDateForDb(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// تنسيق المبلغ مع الفاصلة
  static String formatAmount(double amount) {
    final f = NumberFormat('#,##0.##', 'en');
    return f.format(amount.abs());
  }

  /// اسم ملف النسخة الاحتياطية
  static String backupFileName() {
    final now = DateTime.now();
    return 'daftar_backup_${DateFormat('yyyy_MM_dd_HH_mm').format(now)}.db';
  }
}

/// حساب الرصيد من قيمة in و out
/// in=1  => حركة له (دائن) : تُضاف للرصيد
/// in=-1 => حركة عليه (مدين) : تُطرح من الرصيد
/// يمكن تعديل هذا الحساب من مكان واحد هنا فقط
class BalanceHelper {
  static double calcTransactionValue(int inFlag, double outVal) {
    return inFlag == 1 ? outVal : -outVal;
  }

  static double calcBalance(List<Map<String, dynamic>> transactions) {
    double balance = 0;
    for (final t in transactions) {
      final inFlag = (t['in'] as num?)?.toInt() ?? 0;
      final outVal = (t['out'] as num?)?.toDouble() ?? 0.0;
      balance += calcTransactionValue(inFlag, outVal);
    }
    return balance;
  }

  /// وصف نوع الحركة بالعربية
  static String transactionLabel(int inFlag) {
    return inFlag == 1 ? 'له' : 'عليه';
  }
}

