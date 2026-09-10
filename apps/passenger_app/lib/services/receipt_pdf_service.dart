import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPdfService {
  static const PdfColor darkNavy = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor cardNavy = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor emeraldGreen = PdfColor.fromInt(0xFF10B981);
  static const PdfColor amberGold = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor textLight = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor borderLine = PdfColor.fromInt(0xFF334155);
  static const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);

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
    int? waitFareNgn,
    int? waitMinutes,
    int? baseFareNgn,
  }) async {
    final pdf = pw.Document(
      title: 'Giga Ride Receipt #$shortId',
      author: 'Pickpadi Global Ltd',
    );

    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    // Clean monetary string: Use NGN everywhere in PDF to prevent character glyph corruption
    final rawAmount = fareFormatted.replaceAll('₦', '').replaceAll('NGN', '').trim();
    final ngnFare = 'NGN $rawAmount';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              color: darkNavy,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              border: pw.Border.all(color: borderLine, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header: Logo & Branding
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        if (logoBytes != null)
                          pw.Container(
                            width: 42,
                            height: 42,
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
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.Text(
                              'Pickpadi Global Ltd (RC Registered)',
                              style: const pw.TextStyle(
                                color: emeraldGreen,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: emeraldGreen,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'PAID & SETTLED',
                        style: pw.TextStyle(
                          color: darkNavy,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),
                pw.Divider(color: borderLine, thickness: 1),
                pw.SizedBox(height: 14),

                // Meta Info Grid
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RECEIPT / INVOICE REF', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                        pw.SizedBox(height: 2),
                        pw.Text('GIGA-$shortId', style: pw.TextStyle(color: textLight, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DATE & TIME', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                        pw.SizedBox(height: 2),
                        pw.Text(date, style: pw.TextStyle(color: textLight, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT METHOD', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                        pw.SizedBox(height: 2),
                        pw.Text(paymentMethod, style: pw.TextStyle(color: amberGold, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),

                // Itinerary Section
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
                      pw.Text('TRIP ITINERARY', style: pw.TextStyle(color: emeraldGreen, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            margin: const pw.EdgeInsets.only(top: 3, right: 10),
                            decoration: const pw.BoxDecoration(color: emeraldGreen, shape: pw.BoxShape.circle),
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
                            margin: const pw.EdgeInsets.only(top: 3, right: 10),
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

                // Driver & Vehicle Card
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
                          pw.Text('VERIFIED DRIVER PARTNER', style: pw.TextStyle(color: emeraldGreen, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(driverName, style: pw.TextStyle(color: textLight, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('100% Fare Payout Kept (0% Commission Platform)', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('VEHICLE & PLATE', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                          pw.SizedBox(height: 4),
                          pw.Text(vehicle, style: pw.TextStyle(color: textLight, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(plate, style: pw.TextStyle(color: amberGold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // Financial Itemized Breakdown
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
                          pw.Text(
                            baseFareNgn != null ? 'NGN ${baseFareNgn.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}.00' : ngnFare,
                            style: pw.TextStyle(color: textLight, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      if (waitFareNgn != null && waitFareNgn > 0) ...[
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Stopover Wait Time (${waitMinutes ?? 0} mins)', style: const pw.TextStyle(color: amberGold, fontSize: 11)),
                            pw.Text('NGN ${waitFareNgn.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}.00', style: pw.TextStyle(color: amberGold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Lagos State MOT Road Safety Levy', style: const pw.TextStyle(color: textMuted, fontSize: 11)),
                          pw.Text('NGN 50.00 (Included)', style: const pw.TextStyle(color: textMuted, fontSize: 11)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Giga Platform Commission (0%)', style: const pw.TextStyle(color: emeraldGreen, fontSize: 11)),
                          pw.Text('NGN 0.00 (0% Cut)', style: pw.TextStyle(color: emeraldGreen, fontSize: 11, fontWeight: pw.FontWeight.bold)),
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
                            ngnFare,
                            style: pw.TextStyle(color: amberGold, fontSize: 18, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Security & Authenticity Stamp
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: emeraldGreen, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          '*** AUTHENTIC ELECTRONIC TAX RECEIPT • PICKPADI GLOBAL LTD ***',
                          style: const pw.TextStyle(color: emeraldGreen, fontSize: 7, letterSpacing: 0.8),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Support & Legal Verification: support@getgigaride.com • Lagos, Nigeria',
                        style: const pw.TextStyle(color: textMuted, fontSize: 8),
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
