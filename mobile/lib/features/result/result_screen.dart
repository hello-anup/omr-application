import 'package:flutter/material.dart';

import '../../models/omr_result.dart';
import '../../services/database/database_service.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.examId,
    this.studentRoll,
    this.examName,
    this.answerKey = const {},
  });

  final OmrResult result;
  final int? examId;
  final String? studentRoll;
  final String? examName;
  final Map<int, String?> answerKey;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _saveEvaluation();
  }

  Future<void> _saveEvaluation() async {
    final examId = widget.examId;
    final roll = widget.studentRoll;
    if (_isSaved || _isSaving) return;
    if (examId == null ||
        roll == null ||
        roll.isEmpty ||
        widget.answerKey.isEmpty) {
      return;
    }

    _isSaving = true;
    try {
      await DatabaseService.instance.saveStudentEvaluation(
        examId: examId,
        studentRoll: roll,
        score: correctCount,
        totalQuestions: scoreTotal,
        correctCount: correctCount,
        wrongCount: wrongCount,
        blankCount: blankCount,
      );

      if (!mounted) return;
      setState(() {
        _isSaved = true;
      });
    } catch (_) {
    } finally {
      _isSaving = false;
    }
  }

  String? _clean(String? value) {
    final cleaned = value?.trim().toUpperCase();
    if (cleaned == null || cleaned.isEmpty || cleaned == 'BLANK') return null;

    const banglaToEnglish = {'ক': 'A', 'খ': 'B', 'গ': 'C', 'ঘ': 'D'};

    return banglaToEnglish[cleaned] ?? cleaned;
  }

  String? _keyFor(int questionNumber) {
    return _clean(widget.answerKey[questionNumber]);
  }

  String? _selectedFor(DetectedAnswer answer) {
    return _clean(answer.selectedOption);
  }

  bool _isCorrect(DetectedAnswer answer) {
    final hasKey = widget.answerKey.containsKey(answer.questionNumber);
    if (!hasKey) return false;

    final key = _keyFor(answer.questionNumber);
    final selected = _selectedFor(answer);

    // Special rule: If answer key is Blank/null, EVERY student gets mark
    if (key == null) return true;
    return selected != null && key == selected;
  }

  bool _isWrong(DetectedAnswer answer) {
    final hasKey = widget.answerKey.containsKey(answer.questionNumber);
    if (!hasKey) return false;

    final key = _keyFor(answer.questionNumber);
    final selected = _selectedFor(answer);

    // Blank answer key gives free mark, so it is never wrong
    if (key == null) return false;
    return selected != null && selected != key;
  }

  bool _isBlank(DetectedAnswer answer) {
    final hasKey = widget.answerKey.containsKey(answer.questionNumber);
    if (!hasKey) return _selectedFor(answer) == null;

    final key = _keyFor(answer.questionNumber);
    final selected = _selectedFor(answer);

    // If key is null, question counts as correct (free mark)
    if (key == null) return false;
    return selected == null;
  }

  int get correctCount => widget.result.answers.where(_isCorrect).length;

  int get wrongCount => widget.result.answers.where(_isWrong).length;

  int get blankCount => widget.result.answers.where(_isBlank).length;

  int get scoreTotal => widget.answerKey.isNotEmpty
      ? widget.answerKey.length
      : widget.result.totalQuestions;

  int get answeredCount =>
      widget.result.answers.where((a) => _selectedFor(a) != null).length;

  double get scorePercentage =>
      scoreTotal == 0 ? 0.0 : (correctCount / scoreTotal) * 100.0;

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.answerKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.fact_check_outlined, size: 42),
                        if (_isSaved)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Result saved successfully',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_isSaving)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Saving result...',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasKey ? 'Evaluation result' : 'OMR detection result',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (widget.examName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.examName!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (widget.studentRoll != null &&
                        widget.studentRoll!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Student Roll: ${widget.studentRoll}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(widget.result.imageName),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (hasKey) ...[
              _ScoreCard(
                studentRoll: widget.studentRoll,
                total: scoreTotal,
                answered: answeredCount,
                correct: correctCount,
                wrong: wrongCount,
                blank: blankCount,
                score: correctCount,
                percentage: scorePercentage,
              ),
              const SizedBox(height: 18),
            ],
            _SummaryRow(result: widget.result),
            const SizedBox(height: 22),
            Text(
              'Detected answers',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final answer in widget.result.answers) ...[
              _AnswerTile(
                answer: answer,
                selectedAnswer: _selectedFor(answer),
                correctAnswer: _keyFor(answer.questionNumber),
                isCorrect: _isCorrect(answer),
                isWrong: _isWrong(answer),
                isFreeMark: hasKey && _keyFor(answer.questionNumber) == null,
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Finish Review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.studentRoll,
    required this.total,
    required this.answered,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.score,
    required this.percentage,
  });

  final String? studentRoll;
  final int total;
  final int answered;
  final int correct;
  final int wrong;
  final int blank;
  final int score;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Score: $score/$total (${percentage.toStringAsFixed(1)}%)',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (studentRoll != null && studentRoll!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Roll: $studentRoll',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricChip(label: 'Total', value: total.toString()),
                _MetricChip(label: 'Answered', value: answered.toString()),
                _MetricChip(
                  label: 'Correct',
                  value: correct.toString(),
                  color: Colors.green,
                ),
                _MetricChip(
                  label: 'Wrong',
                  value: wrong.toString(),
                  color: colorScheme.error,
                ),
                _MetricChip(label: 'Blank', value: blank.toString()),
                _MetricChip(
                  label: 'Score',
                  value: '$score',
                  color: colorScheme.primary,
                ),
                _MetricChip(
                  label: 'Percent',
                  value: '${percentage.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.surfaceContainerHighest)
            .withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.result});

  final OmrResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Questions',
            value: result.totalQuestions.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Answered',
            value: result.answeredQuestions.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Review',
            value: result.needsReviewCount.toString(),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.answer,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.isWrong,
    this.isFreeMark = false,
  });

  final DetectedAnswer answer;
  final String? selectedAnswer;
  final String? correctAnswer;
  final bool isCorrect;
  final bool isWrong;
  final bool isFreeMark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shownSelected = selectedAnswer ?? 'Blank';

    final keyLabel = isFreeMark
        ? 'Key: Blank (Free Mark)'
        : correctAnswer == null
        ? null
        : 'Key: $correctAnswer';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isCorrect
                  ? Colors.green.withValues(alpha: 0.18)
                  : isWrong
                  ? colorScheme.errorContainer
                  : colorScheme.secondaryContainer,
              child: Text(answer.questionNumber.toString()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                keyLabel == null
                    ? 'Question ${answer.questionNumber}'
                    : 'Question ${answer.questionNumber} | $keyLabel',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              shownSelected,
              style: TextStyle(
                color: isCorrect
                    ? Colors.green
                    : isWrong
                    ? colorScheme.error
                    : colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
