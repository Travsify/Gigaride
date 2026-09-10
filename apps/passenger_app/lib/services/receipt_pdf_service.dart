import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPdfService {
  static const PdfColor darkNavy = PdfColor.fromInt(0xFF0A1628);
  static const PdfColor cardNavy = PdfColor.fromInt(0xFF131C31);
  static const PdfColor tealPrimary = PdfColor.fromInt(0xFF2DC79F);
  static const PdfColor amberGold = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor textLight = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor borderLine = PdfColor.fromInt(0xFF2D3748);

  static Future<void> generateAndShare({
    required String shortId,
    required String date,
    required String pickup,
    required String dropoff,
    required String driverName,
    required String vehicle,
    required String plate,
    required String fareFormatted,
    required String paymentMethod,
  }) async {
    final pdf = pw.Document(
      title: 'Giga Ride Receipt #',
      author: 'Pickpadi Global Ltd',
    );

    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              color: darkNavy,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              border: pw.Border.all(color: borderLine, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (logoBytes != null)
                          pw.Container(
                            width: 36,
                            height: 36,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.Image(pw.MemoryImage(logoBytes)),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'GIGA RIDE',
                              style: pw.TextStyle(
                                color: textLight,
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.Text(
                              'Giga is a Product of Pickpadi Global Ltd',
                              style: const pw.TextStyle(
                                color: tealPrimary,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: const pw.BoxDecoration(
                        color: tealPrimary,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'SETTLED & VERIFIED',
                        style: pw.TextStyle(
                          color: darkNavy,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: borderLine, thickness: 1),
                pw.SizedBox(height: 14),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RECEIPT NUMBER', style: const pw.TextStyle(color: textMuted, fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text('#', style: pw.TextStyle(color: textLight, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DATE & TIME', style: const pw.TextStyle(color: textMuted, fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text(date, style: pw.TextStyle(color: textLight, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT METHOD', style: const pw.TextStyle(color: textMuted, fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text(paymentMethod, style: pw.TextStyle(color: amberGold, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: cardNavy,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: borderLine),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TRIP ITINERARY', style: pw.TextStyle(color: tealPrimary, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            margin: const pw.EdgeInsets.only(top: 3, right: 8),
                            decoration: const pw.BoxDecoration(color: tealPrimary, shape: pw.BoxShape.circle),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('PICKUP LOCATION', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                                pw.Text(pickup, style: pw.TextStyle(color: textLight, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(left: 3.5),
                        height: 14,
                        child: pw.VerticalDivider(color: borderLine, thickness: 1.5),
                      ),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            margin: const pw.EdgeInsets.only(top: 3, right: 8),
                            decoration: const pw.BoxDecoration(color: amberGold, shape: pw.BoxShape.circle),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('DESTINATION', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                                pw.Text(dropoff, style: pw.TextStyle(color: textLight, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: cardNavy,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: borderLine),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('VERIFIED DRIVER', style: pw.TextStyle(color: tealPrimary, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(driverName, style: pw.TextStyle(color: textLight, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('100% Fare Payout Kept (0% Commission)', style: const pw.TextStyle(color: textMuted, fontSize: 9)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('VEHICLE & PLATE', style: const pw.TextStyle(color: textMuted, fontSize: 9)),
                          pw.SizedBox(height: 4),
                          pw.Text(vehicle, style: pw.TextStyle(color: textLight, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(plate, style: pw.TextStyle(color: amberGold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: cardNavy,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: borderLine),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Base Transportation Fare', style: const pw.TextStyle(color: textMuted, fontSize: 11)),
                          pw.Text(fareFormatted, style: pw.TextStyle(color: textLight, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Giga Platform Commission (0%)', style: const pw.TextStyle(color: tealPrimary, fontSize: 11)),
                          pw.Text('NGN 0.00', style: const pw.TextStyle(color: tealPrimary, fontSize: 11)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Driver Payout (100% Kept by Driver)', style: const pw.TextStyle(color: textMuted, fontSize: 11)),
                          pw.Text(fareFormatted, style: const pw.TextStyle(color: textLight, fontSize: 11)),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Divider(color: borderLine, thickness: 1),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL AMOUNT PAID', style: pw.TextStyle(color: textLight, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            fareFormatted,
                            style: pw.TextStyle(color: amberGold, fontSize: 18, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'This document is an authentic electronic transaction receipt generated by GigaRide.',
                        style: const pw.TextStyle(color: textMuted, fontSize: 8),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Giga is a Product of Pickpadi Global Ltd • Support: support@getgigaride.com • Nigeria',
                        style: pw.TextStyle(color: tealPrimary, fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'GigaReceipt-$shortId.pdf',
    );
  }
}
