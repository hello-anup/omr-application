import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/omr_sheet_generator_service.dart';

void main() {
  test('OmrSheetGeneratorService generates valid PDF bytes with custom details', () async {
    // 1x1 transparent PNG bytes for dummy template and logo in test environment
    final dummyPngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );

    final service = OmrSheetGeneratorService.instance;

    final pdfBytes = await service.generateCustomOmrPdf(
      institutionName: 'Dhaka Residential Model College',
      institutionAddress: 'Mohammadpur, Dhaka - 1207',
      logoBytes: dummyPngBytes,
      templateImageBytes: dummyPngBytes,
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(100));

    // Valid PDF starts with %PDF-
    final header = utf8.decode(pdfBytes.sublist(0, 5));
    expect(header, '%PDF-');
  });
}
