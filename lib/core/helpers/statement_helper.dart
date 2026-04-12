import '../../data/models/transaction.dart' as tx_model;
import 'format_helper.dart';

class StatementHelper {
  static String buildArabicStatement({
    required String customerName,
    required String currencyName,
    required double currentBalance,
    required double finalBalance,
    required List<tx_model.Transaction> transactions,
  }) {
    double totalIn = 0;
    double totalOut = 0;
    final buffer = StringBuffer();

    buffer.writeln('*كشف حساب عميل*');
    buffer.writeln('👤 العميل: $customerName');
    buffer.writeln('💱 العملة: $currencyName');
    buffer.writeln(
      '💰 الرصيد الحالي: ${FormatHelper.formatAmount(currentBalance)} $currencyName',
    );
    buffer.writeln('');
    buffer.writeln('🧾 قائمة الحركات:');

    if (transactions.isEmpty) {
      buffer.writeln('- لا توجد حركات');
    } else {
      for (final tx in transactions) {
        final label = BalanceHelper.transactionLabel(tx.inFlag);
        final amount = FormatHelper.formatAmount(tx.out);
        final date = FormatHelper.formatDate(tx.date);

        buffer.writeln('- $date | $label | $amount');

        if ((tx.remarks ?? '').trim().isNotEmpty) {
          buffer.writeln('  ملاحظة: ${tx.remarks!.trim()}');
        }

        if (tx.inFlag == 1) {
          totalIn += tx.out;
        } else {
          totalOut += tx.out;
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('إجمالي مطلوب: ${FormatHelper.formatAmount(totalIn)}');
    buffer.writeln('إجمالي مدفوع: ${FormatHelper.formatAmount(totalOut)}');
    buffer.writeln(
      'الرصيد النهائي: ${FormatHelper.formatAmount(finalBalance)} $currencyName',
    );

    return buffer.toString();
  }
}

