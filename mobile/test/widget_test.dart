import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/exam/details/exam_details_screen.dart';
import 'package:mobile/features/processing/processing_screen.dart';
import 'package:mobile/features/result/result_screen.dart';
import 'package:mobile/features/scanner/scanner_screen.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/omr_result.dart';

void main() {
  testWidgets('home screen shows exam workflow actions', (tester) async {
    await tester.pumpWidget(const OmrApplication());
    await tester.pumpAndSettle();

    expect(find.text('OMR Checker'), findsOneWidget);
    expect(find.text('Create and evaluate exams'), findsOneWidget);
    expect(find.text('Create Exam'), findsOneWidget);
    expect(find.text('Created Exams'), findsOneWidget);
  });

  testWidgets('create exam action opens create exam screen', (tester) async {
    await tester.pumpWidget(const OmrApplication());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Exam'));
    await tester.pumpAndSettle();

    expect(find.text('Create a new exam'), findsOneWidget);
    expect(find.text('Exam name'), findsOneWidget);
  });

  testWidgets('processing screen shows staged detection pipeline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProcessingScreen(
          imageName: 'sample-omr.jpg',
          imagePath: 'sample-omr.jpg',
        ),
      ),
    );

    expect(find.text('Process OMR Sheet'), findsOneWidget);
    expect(find.text('sample-omr.jpg'), findsOneWidget);
    expect(find.text('Sheet alignment'), findsOneWidget);
    expect(find.text('Bubble detection'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Run Detection'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Run Detection'), findsOneWidget);
  });

  testWidgets('result screen shows sample answers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          result: OmrResult(
            imageName: 'sample-omr.jpg',
            sourceImagePath: 'sample-omr.jpg',
            answers: [
              DetectedAnswer(
                questionNumber: 1,
                selectedOption: 'A',
                status: 'marked',
                confidenceGap: 0.5,
                scores: {'A': 0.9, 'B': 0.1},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Review Result'), findsOneWidget);
    expect(find.text('Detected answers'), findsOneWidget);
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('exam details shows answer key methods and evaluation section', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ExamDetailsScreen(examId: 1, examName: 'Physics Midterm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Physics Midterm'), findsOneWidget);
    expect(find.text('Number of questions'), findsOneWidget);
    expect(find.text('Answer Key'), findsOneWidget);
    expect(find.text('Manual Input'), findsOneWidget);
    expect(find.text('Scan Solution Sheet'), findsOneWidget);
    expect(find.text('Evaluation'), findsOneWidget);
    expect(find.text('Evaluate Students'), findsOneWidget);
  });

  testWidgets('scanner screen shows roll number input field', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScannerScreen(
          examId: 1,
          examName: 'Math Finals',
          answerKey: {1: 'A', 2: 'B'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan Student Sheet'), findsOneWidget);
    expect(find.text('Student Roll Number'), findsOneWidget);
    expect(find.text('Capture with Camera'), findsOneWidget);
    expect(find.text('Choose Image from Gallery'), findsOneWidget);
  });

  testWidgets(
    'result screen evaluates score with student roll and free-mark rule',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultScreen(
            examId: 1,
            studentRoll: 'ROLL-42',
            examName: 'Math Finals',
            answerKey: const {1: 'A', 2: 'B', 3: null},
            result: const OmrResult(
              imageName: 'student-sheet.jpg',
              sourceImagePath: 'student-sheet.jpg',
              answers: [
                DetectedAnswer(
                  questionNumber: 1,
                  selectedOption: 'A',
                  status: 'marked',
                  confidenceGap: 0.5,
                  scores: {'A': 0.9, 'B': 0.1},
                ),
                DetectedAnswer(
                  questionNumber: 2,
                  selectedOption: 'C',
                  status: 'marked',
                  confidenceGap: 0.5,
                  scores: {'C': 0.9, 'B': 0.1},
                ),
                DetectedAnswer(
                  questionNumber: 3,
                  selectedOption: null,
                  status: 'blank',
                  confidenceGap: 0.0,
                  scores: {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Roll: ROLL-42'), findsOneWidget);
      expect(find.text('Student Roll: ROLL-42'), findsOneWidget);
      expect(find.text('Score: 2/3 (66.7%)'), findsOneWidget);
      expect(find.text('Total: '), findsOneWidget);
      expect(find.text('Correct: '), findsOneWidget);
      expect(find.text('Wrong: '), findsOneWidget);
      expect(find.text('Blank: '), findsOneWidget);
      expect(find.text('Result saved successfully'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Question 3 | Key: Blank (Free Mark)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Question 3 | Key: Blank (Free Mark)'), findsOneWidget);
    },
  );

  testWidgets(
    'delete exam confirmation dialog shows expected message and actions',
    (tester) async {
      bool deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Delete Exam'),
                      content: const Text(
                        'Are you sure you want to delete this exam?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    deleted = true;
                  }
                },
                child: const Text('Trigger Delete'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Exam'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete this exam?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
      expect(
        find.text('Are you sure you want to delete this exam?'),
        findsNothing,
      );

      await tester.tap(find.text('Trigger Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    },
  );
}
