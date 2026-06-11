import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/customer.dart';
import '../../data/models/currency.dart';
import '../../data/models/transaction.dart' as tx_model;
import '../helpers/format_helper.dart';

class PdfService {
  static Future<void> shareStatement({
    required Customer customer,
    required Currency currency,
    required List<tx_model.Transaction> transactions,
    required double balance,
  }) async {
    final fontData =
        await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final arabicFont = pw.Font.ttf(fontData);

    double totalIn = 0;
    double totalOut = 0;
    final finalBalance = transactions.fold<double>(
      0,
      (sum, tx) => tx.inFlag == 1 ? sum + tx.out : sum - tx.out,
    );
    for (final tx in transactions) {
      if (tx.inFlag == 1) {
        totalIn += tx.out;
      } else {
        totalOut += tx.out;
      }
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: arabicFont),
      build: (ctx) => [
        _buildHeader(customer, currency, balance, arabicFont),
        pw.SizedBox(height: 12),
        _buildSummaryRow(totalIn, totalOut, finalBalance, currency.displayName, arabicFont),
        pw.SizedBox(height: 16),
        _buildTransactionsTable(transactions, currency.displayName, arabicFont),
      ],
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'كشف_${customer.name}_${currency.displayName}.pdf',
    );
  }

  static pw.Widget _buildHeader(
    Customer customer,
    Currency currency,
    double balance,
    pw.Font font,
  ) {
    final balanceColor = balance >= 0 ? PdfColors.green800 : PdfColors.red800;
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('كشف حساب عميل',
              style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Text('العميل: ', style: pw.TextStyle(font: font, color: PdfColors.grey600)),
            pw.Text(customer.name, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Row(children: [
            pw.Text('العملة: ', style: pw.TextStyle(font: font, color: PdfColors.grey600)),
            pw.Text(currency.displayName, style: pw.TextStyle(font: font)),
          ]),
          pw.Row(children: [
            pw.Text('الرصيد: ', style: pw.TextStyle(font: font, color: PdfColors.grey600)),
            pw.Text(
              '${FormatHelper.formatAmount(balance)} ${currency.displayName}',
              style: pw.TextStyle(font: font, color: balanceColor, fontWeight: pw.FontWeight.bold),
            ),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    double totalIn,
    double totalOut,
    double finalBalance,
    String currName,
    pw.Font font,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _summaryCell('إجمالي مطلوب', FormatHelper.formatAmount(totalIn),
            PdfColors.green800, font),
        _summaryCell('إجمالي مدفوع', FormatHelper.formatAmount(totalOut),
            PdfColors.red800, font),
        _summaryCell('الرصيد النهائي',
            '${FormatHelper.formatAmount(finalBalance)} $currName',
            finalBalance >= 0 ? PdfColors.green800 : PdfColors.red800, font),
      ],
    );
  }

  static pw.Widget _summaryCell(
      String title, String value, PdfColor color, pw.Font font) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(font: font, fontSize: 11, color: color,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTransactionsTable(
    List<tx_model.Transaction> transactions,
    String currName,
    pw.Font font,
  ) {
    final headers = ['التاريخ', 'النوع', 'المبلغ', 'ملاحظة'];
    final rows = transactions.map((tx) {
      final label = BalanceHelper.transactionLabel(tx.inFlag);
      return [
        FormatHelper.formatDate(tx.date),
        label,
        '${FormatHelper.formatAmount(tx.out)} $currName',
        tx.remarks ?? '',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          font: font, fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }
}
