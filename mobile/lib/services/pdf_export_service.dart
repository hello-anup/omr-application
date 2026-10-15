import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/exam.dart';

class PdfExportService {
  PdfExportService._();

  static final PdfExportService instance = PdfExportService._();

  Future<Uint8List> generateExamResultPdf({
    required String examName,
    required List<StudentEvaluation> evaluations,
  }) async {
    final pdf = pw.Document();

    final sortedEvaluations = List<StudentEvaluation>.from(evaluations)
      ..sort((a, b) => b.score.compareTo(a.score));

    final totalStudents = sortedEvaluations.length;
    final highestScore = sortedEvaluations.isEmpty ? 0 : sortedEvaluations.first.score;
    final averageScore = sortedEvaluations.isEmpty
        ? 0.0
        : sortedEvaluations.map((e) => e.score).reduce((a, b) => a + b) / totalStudents;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'OMR Evaluation Result Sheet',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Exam: $examName',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Generated on: ${DateTime.now().toLocal().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Total Students', '$totalStudents'),
                _buildSummaryItem('Highest Score', '$highestScore'),
                _buildSummaryItem('Average Score', averageScore.toStringAsFixed(1)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'Rank',
              'Roll',
              'Score',
              'Percentage',
              'Correct',
              'Wrong',
              'Blank',
            ],
            data: List.generate(sortedEvaluations.length, (index) {
              final student = sortedEvaluations[index];
              return [
                '${index + 1}',
                student.studentRoll,
                '${student.score}/${student.totalQuestions}',
                '${student.percentage.toStringAsFixed(1)}%',
                '${student.correctCount}',
                '${student.wrongCount}',
                '${student.blankCount}',
              ];
            }),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.indigo700,
            ),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryItem(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo800,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }
}
