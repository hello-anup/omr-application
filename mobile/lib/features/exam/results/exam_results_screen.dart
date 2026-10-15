import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../models/exam.dart';
import '../../../services/database/database_service.dart';
import '../../../services/pdf_export_service.dart';

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({
    super.key,
    required this.examId,
    required this.examName,
  });

  final int examId;
  final String examName;

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  List<StudentEvaluation> _evaluations = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final results = await DatabaseService.instance.getEvaluationsForExam(
      widget.examId,
    );

    if (!mounted) return;

    setState(() {
      _evaluations = results..sort((a, b) => b.score.compareTo(a.score));
      _isLoading = false;
    });
  }

  Future<void> _exportPdf() async {
    if (_evaluations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student evaluations to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdfBytes = await PdfExportService.instance.generateExamResultPdf(
        examName: widget.examName,
        evaluations: _evaluations,
      );

      // Save PDF into application files directory
      final baseDir = await getDatabasesPath();
      final sanitizedName = widget.examName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = 'result_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = p.join(baseDir, fileName);

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          title: const Text('PDF Exported Successfully'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The evaluation sheet has been saved on this mobile device:'),
              const SizedBox(height: 12),
              SelectableText(
                filePath,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.examName} - Results'),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _isExporting ? null : _exportPdf,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _evaluations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No student results found.',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Scan student sheets from the exam details screen.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _evaluations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _evaluations[index];
                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == 0
                              ? Colors.amber.shade700
                              : index == 1
                                  ? Colors.blueGrey
                                  : index == 2
                                      ? Colors.brown.shade400
                                      : Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: index < 3
                              ? Colors.white
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          'Roll: ${item.studentRoll}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Correct: ${item.correctCount} | Wrong: ${item.wrongCount} | Blank: ${item.blankCount}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.score}/${item.totalQuestions}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              '${item.percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
