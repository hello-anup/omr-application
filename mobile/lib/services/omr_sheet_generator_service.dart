import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OmrSheetGeneratorService {
  OmrSheetGeneratorService._();
  static final instance = OmrSheetGeneratorService._();

  static const double templateWidth = 1370.0;
  static const double templateHeight = 2048.0;

  Future<Uint8List> generateCustomOmrPdf({
    required String institutionName,
    required String institutionAddress,
    Uint8List? logoBytes,
    Uint8List? templateImageBytes,
  }) async {
    final pdf = pw.Document();

    final templateBytes = templateImageBytes ??
        (await rootBundle.load('assets/images/template_omr.png'))
            .buffer
            .asUint8List();

    final templateImage = pw.MemoryImage(templateBytes);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    const pageFormat = PdfPageFormat.a4;
    final availableWidth = pageFormat.availableWidth;
    final availableHeight = pageFormat.availableHeight;

    // Scale to fit available A4 area while preserving 1370:2048 ratio
    final scale = (availableWidth / templateWidth)
        .clamp(0.0, availableHeight / templateHeight);
    final renderWidth = templateWidth * scale;
    final renderHeight = templateHeight * scale;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        build: (context) {
          return pw.Center(
            child: pw.SizedBox(
              width: renderWidth,
              height: renderHeight,
              child: pw.Stack(
                children: [
                  // Base OMR template
                  pw.Positioned.fill(
                    child: pw.Image(templateImage, fit: pw.BoxFit.fill),
                  ),

                  // Cover "Universal OMR sheet", "Institution Name", "Institution Address"
                  pw.Positioned(
                    left: (375.0 / templateWidth) * renderWidth,
                    top: (10.0 / templateHeight) * renderHeight,
                    child: pw.SizedBox(
                      width: ((1005.0 - 375.0) / templateWidth) * renderWidth,
                      height: ((195.0 - 10.0) / templateHeight) * renderHeight,
                      child: pw.Container(
                        color: PdfColors.white,
                        alignment: pw.Alignment.center,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            if (institutionName.trim().isNotEmpty)
                              pw.Text(
                                institutionName.trim(),
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize:
                                      (renderWidth * 0.038).clamp(12.0, 20.0),
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                            if (institutionAddress.trim().isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                institutionAddress.trim(),
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize:
                                      (renderWidth * 0.024).clamp(8.0, 12.0),
                                  color: PdfColors.grey900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Cover "Logo" text inside the Logo box and place custom logo
                  pw.Positioned(
                    left: (547.0 / templateWidth) * renderWidth,
                    top: (203.0 / templateHeight) * renderHeight,
                    child: pw.SizedBox(
                      width: ((825.0 - 547.0) / templateWidth) * renderWidth,
                      height: ((413.0 - 203.0) / templateHeight) * renderHeight,
                      child: pw.Container(
                        color: PdfColors.white,
                        padding: const pw.EdgeInsets.all(3),
                        alignment: pw.Alignment.center,
                        child: logoImage != null
                            ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                            : pw.SizedBox(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
