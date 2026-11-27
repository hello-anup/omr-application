import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/omr_result.dart';
import 'package:mobile/services/evaluation_service.dart';

void main() {
  test('EvaluationService computes scores and respects free mark for null answer key', () {
    const service = EvaluationService.instance;
    final answers = [
      const DetectedAnswer(
        questionNumber: 1,
        selectedOption: 'A',
        status: 'marked',
        confidenceGap: 1.0,
        scores: {},
      ),
      const DetectedAnswer(
        questionNumber: 2,
        selectedOption: 'B',
        status: 'marked',
        confidenceGap: 1.0,
        scores: {},
      ),
      const DetectedAnswer(
        questionNumber: 3,
        selectedOption: null,
        status: 'blank',
        confidenceGap: 1.0,
        scores: {},
      ),
      const DetectedAnswer(
        questionNumber: 4,
        selectedOption: 'C',
        status: 'marked',
        confidenceGap: 1.0,
        scores: {},
      ),
    ];

    final answerKey = {
      1: 'A', // correct
      2: 'C', // wrong (selected B)
      3: null, // blank key -> free mark even though student left blank!
      4: 'C', // correct
    };

    final result = service.evaluate(answers: answers, answerKey: answerKey);

    expect(result.totalQuestions, 4);
    expect(result.correctCount, 3); // Q1, Q3 (free), Q4
    expect(result.wrongCount, 1); // Q2
    expect(result.blankCount, 0); // Q3 became correct due to free mark
    expect(result.score, 3);
    expect(result.percentage, 75.0);
  });

  test('EvaluationService enforces single-key vs free-mark rules for multi-marked student sheets', () {
    const service = EvaluationService.instance;
    final answers = [
      const DetectedAnswer(
        questionNumber: 1,
        selectedOption: null,
        status: 'ambiguous',
        confidenceGap: 5.0,
        scores: {},
      ),
      const DetectedAnswer(
        questionNumber: 2,
        selectedOption: null,
        status: 'ambiguous',
        confidenceGap: 5.0,
        scores: {},
      ),
      const DetectedAnswer(
        questionNumber: 3,
        selectedOption: null,
        status: 'blank',
        confidenceGap: 2.0,
        scores: {},
      ),
    ];

    final answerKey = {
      1: 'A', // single right answer -> multi-marked student gets 0 (wrong)
      2: null, // blank/multi-marked key -> multi-marked student gets free mark
      3: 'B', // single right answer -> blank student gets 0 (blank)
    };

    final result = service.evaluate(answers: answers, answerKey: answerKey);

    expect(result.totalQuestions, 3);
    expect(result.correctCount, 1);
    expect(result.wrongCount, 1);
    expect(result.blankCount, 1);
    expect(result.score, 1);
  });
}
