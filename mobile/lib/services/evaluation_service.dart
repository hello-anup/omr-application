import '../models/omr_result.dart';

class EvaluationResult {
  const EvaluationResult({
    required this.score,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.blankCount,
  });

  final int score;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int blankCount;

  double get percentage =>
      totalQuestions == 0 ? 0.0 : (score / totalQuestions) * 100.0;
}

class EvaluationService {
  const EvaluationService._();
  static const instance = EvaluationService._();

  static String? cleanOption(String? value) {
    final cleaned = value?.trim().toUpperCase();
    if (cleaned == null || cleaned.isEmpty || cleaned == 'BLANK') return null;
    const banglaToEnglish = {'ক': 'A', 'খ': 'B', 'গ': 'C', 'ঘ': 'D'};
    return banglaToEnglish[cleaned] ?? cleaned;
  }

  EvaluationResult evaluate({
    required List<DetectedAnswer> answers,
    required Map<int, String?> answerKey,
  }) {
    int correctCount = 0;
    int wrongCount = 0;
    int blankCount = 0;

    for (final answer in answers) {
      final qNum = answer.questionNumber;
      if (!answerKey.containsKey(qNum)) continue;

      final key = cleanOption(answerKey[qNum]);
      final selected = cleanOption(answer.selectedOption);

      if (key == null) {
        // Free mark rule: If answer key is Blank/null, EVERY student gets mark
        correctCount++;
      } else if (selected == null) {
        blankCount++;
      } else if (selected == key) {
        correctCount++;
      } else {
        wrongCount++;
      }
    }

    final totalQuestions =
        answerKey.isNotEmpty ? answerKey.length : answers.length;

    return EvaluationResult(
      score: correctCount,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      wrongCount: wrongCount,
      blankCount: blankCount,
    );
  }
}
