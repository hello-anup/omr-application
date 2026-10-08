class OmrResult {
  const OmrResult({
    required this.imageName,
    required this.sourceImagePath,
    required this.answers,
    this.templateId,
    this.summary,
    this.note,
  });

  final String imageName;
  final String sourceImagePath;
  final List<DetectedAnswer> answers;
  final String? templateId;
  final OmrSummary? summary;
  final String? note;

  int get totalQuestions => answers.length;
  int get answeredQuestions =>
      answers.where((answer) => answer.selectedOption != null).length;
  int get needsReviewCount =>
      answers.where((answer) => answer.needsReview).length;

  factory OmrResult.fromApiJson(
    Map<String, dynamic> json, {
    required String imageName,
    required String sourceImagePath,
  }) {
    final rawAnswers = json['answers'];
    final answers = rawAnswers is List
        ? rawAnswers
              .whereType<Map>()
              .map(
                (item) =>
                    DetectedAnswer.fromApiJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <DetectedAnswer>[];

    final rawSummary = json['summary'];

    return OmrResult(
      imageName: imageName,
      sourceImagePath: sourceImagePath,
      answers: answers,
      templateId: json['template_id']?.toString(),
      summary: rawSummary is Map
          ? OmrSummary.fromApiJson(Map<String, dynamic>.from(rawSummary))
          : null,
      note: json['note']?.toString(),
    );
  }
}

class OmrSummary {
  const OmrSummary({
    required this.totalQuestions,
    required this.marked,
    required this.blank,
    required this.ambiguous,
  });

  final int totalQuestions;
  final int marked;
  final int blank;
  final int ambiguous;

  factory OmrSummary.fromApiJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return OmrSummary(
      totalQuestions: read('total_questions'),
      marked: read('marked'),
      blank: read('blank'),
      ambiguous: read('ambiguous'),
    );
  }
}

class DetectedAnswer {
  const DetectedAnswer({
    required this.questionNumber,
    required this.selectedOption,
    required this.status,
    required this.confidenceGap,
    required this.scores,
  });

  final int questionNumber;
  final String? selectedOption;
  final String status;
  final double confidenceGap;
  final Map<String, double> scores;

  bool get needsReview => status == 'ambiguous';
  bool get isBlank => status == 'blank';
  bool get isMarked => status == 'marked';

  factory DetectedAnswer.fromApiJson(Map<String, dynamic> json) {
    final rawScores = json['scores'];
    final scores = <String, double>{};
    if (rawScores is Map) {
      for (final entry in rawScores.entries) {
        final value = entry.value;
        if (value is num) scores[entry.key.toString()] = value.toDouble();
      }
    }

    return DetectedAnswer(
      questionNumber: (json['question'] as num?)?.toInt() ?? 0,
      selectedOption: json['answer']?.toString(),
      status: json['status']?.toString() ?? 'blank',
      confidenceGap: (json['confidence_gap'] as num?)?.toDouble() ?? 0,
      scores: scores,
    );
  }
}
