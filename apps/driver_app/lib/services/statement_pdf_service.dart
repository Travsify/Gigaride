import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StatementPdfService {
  static const PdfColor primaryTeal = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor accentGreen = PdfColor.fromInt(0xFF10B981);
  static const PdfColor dangerRed = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor darkNavy = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor borderGray = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);

  static Future<Uint8List> buildPdf({
    required String userName,
    required String userEmail,
    required String userPhone,
    required num currentBalanceNgn,
    required List<dynamic> transactions,
    String? nuban,
    String? bankName,
  }) async {
    final pdf = pw.Document(
      title: 'Giga Ride Statement - ',
      author: 'Pickpadi Global Ltd / GigaRide',
    );

    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    final currencyFmt = NumberFormat.currency(locale: 'en_NG', symbol: 'NGN ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final generatedDate = DateFormat('dd MMMM yyyy, hh:mm:ss a').format(DateTime.now());

    // Calculate totals
    num totalInflow = 0;
    num totalOutflow = 0;
    for (final tx in transactions) {
      final amt = ((tx['amount_kobo'] ?? 0) as num) / 100;
      final type = (tx['type'] ?? tx['payment_type'] ?? '').toString();
      final ch = (tx['channel'] ?? '').toString();
      final isOutflow = type.contains('TRIP') ||
          type.contains('DISPUTE') ||
          type.contains('WITHDRAWAL') ||
          ch.contains('WDR') ||
          (tx['reference'] ?? '').toString().contains('WDR');

      if (isOutflow) {
        totalOutflow += amt;
      } else {
        totalInflow += amt;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: borderGray, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logoBytes != null)
                      pw.Container(
                        width: 32,
                        height: 32,
                        margin: const pw.EdgeInsets.only(right: 8),
                        child: pw.Image(pw.MemoryImage(logoBytes)),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'GIGARIDE',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryTeal,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.Text(
                          'Pickpadi Global Ltd • RC 7891234',
                          style: const pw.TextStyle(fontSize: 8, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ACCOUNT STATEMENT',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkNavy),
                    ),
                    pw.Text('Generated: $generatedDate', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderGray, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Electronic Statement • Giga Engine Automated Ledger • Zero Commission Shield',
                  style: const pw.TextStyle(fontSize: 7, color: textMuted),
                ),
                pw.Text(
                  'Page  of ',
                  style: const pw.TextStyle(fontSize: 8, color: textMuted),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: borderGray),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ACCOUNT HOLDER', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                      pw.SizedBox(height: 2),
                      pw.Text(userName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkNavy)),
                      pw.SizedBox(height: 2),
                      pw.Text(' • ', style: const pw.TextStyle(fontSize: 9, color: textMuted)),
                      if (nuban != null && nuban.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Giga NUBAN:  ()', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryTeal)),
                      ],
                    ],
                  ),
                  pw.Row(
                    children: [
                      _buildSummaryPill('TOTAL INFLOW', currencyFmt.format(totalInflow), accentGreen),
                      pw.SizedBox(width: 8),
                      _buildSummaryPill('TOTAL OUTFLOW', currencyFmt.format(totalOutflow), dangerRed),
                      pw.SizedBox(width: 8),
                      _buildSummaryPill('CLOSING BALANCE', currencyFmt.format(currentBalanceNgn), primaryTeal),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TRANSACTION LEDGER ( Records)',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkNavy),
                ),
                pw.Text(
                  'Official Settlement Records',
                  style: const pw.TextStyle(fontSize: 8, color: textMuted),
                ),
              ],
            ),

            pw.SizedBox(height: 6),

            if (transactions.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 30),
                alignment: pw.Alignment.center,
                child: pw.Text('No transactions recorded in statement period.', style: const pw.TextStyle(fontSize: 10, color: textMuted)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.2),
                  1: const pw.FlexColumnWidth(2.4),
                  2: const pw.FlexColumnWidth(3.2),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(2.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: darkNavy),
                    children: [
                      _buildTableHeaderCell('DATE & TIME'),
                      _buildTableHeaderCell('REFERENCE'),
                      _buildTableHeaderCell('DESCRIPTION'),
                      _buildTableHeaderCell('CHANNEL'),
                      _buildTableHeaderCell('STATUS'),
                      _buildTableHeaderCell('AMOUNT (NGN)', alignRight: true),
                    ],
                  ),
                  ...transactions.map((tx) {
                    final amt = ((tx['amount_kobo'] ?? 0) as num) / 100;
                    final type = (tx['type'] ?? tx['payment_type'] ?? '').toString();
                    final ch = (tx['channel'] ?? 'WALLET').toString();
                    final ref = (tx['reference'] ?? tx['id'] ?? 'N/A').toString();
                    final status = (tx['status'] ?? 'SUCCESS').toString().toUpperCase();
                    final isOutflow = type.contains('TRIP') ||
                        type.contains('DISPUTE') ||
                        type.contains('WITHDRAWAL') ||
                        ch.contains('WDR') ||
                        ref.contains('WDR');

                    final desc = tx['meta_data']?['note'] ??
                        tx['meta_data']?['type'] ??
                        (isOutflow ? 'Wallet Debit / Trip Settlement' : 'Wallet Funding / Credit');

                    final formattedDate = tx['created_at'] != null
                        ? dateFmt.format(DateTime.tryParse(tx['created_at'].toString()) ?? DateTime.now())
                        : 'Recent';

                    return pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.white),
                      children: [
                        _buildTableCell(formattedDate, fontSize: 7.5),
                        _buildTableCell(ref, fontSize: 7, isMono: true),
                        _buildTableCell(desc.toString(), fontSize: 7.5),
                        _buildTableCell(ch.replaceAll('_', ' '), fontSize: 7),
                        _buildTableCell(status, fontSize: 7, isBold: true, color: status == 'SUCCESS' ? accentGreen : dangerRed),
                        _buildTableCell(
                          (isOutflow ? "- ₦" : "+ ₦") + amt.toStringAsFixed(2),
                          fontSize: 8,
                          isBold: true,
                          alignRight: true,
                          color: isOutflow ? dangerRed : accentGreen,
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeaderCell(String text, {bool alignRight = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    double fontSize = 8,
    bool isBold = false,
    bool isMono = false,
    bool alignRight = false,
    PdfColor color = textDark,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryPill(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderGray),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: textMuted)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  static Future<void> printStatement({
    required String userName,
    required String userEmail,
    required String userPhone,
    required num currentBalanceNgn,
    required List<dynamic> transactions,
    String? nuban,
    String? bankName,
  }) async {
    final pdfBytes = await buildPdf(
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      currentBalanceNgn: currentBalanceNgn,
      transactions: transactions,
      nuban: nuban,
      bankName: bankName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'GigaRide_Statement_.pdf',
    );
  }

  static Future<void> shareStatement({
    required String userName,
    required String userEmail,
    required String userPhone,
    required num currentBalanceNgn,
    required List<dynamic> transactions,
    String? nuban,
    String? bankName,
  }) async {
    final pdfBytes = await buildPdf(
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      currentBalanceNgn: currentBalanceNgn,
      transactions: transactions,
      nuban: nuban,
      bankName: bankName,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'GigaRide_Statement_.pdf',
    );
  }
}
