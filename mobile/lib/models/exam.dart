class Exam {
  const Exam({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.answerKey,
  });

  final int? id;
  final String name;
  final DateTime createdAt;
  final List<String> answerKey;

  factory Exam.fromMap(Map<String, Object?> map, List<String> answerKey) {
    return Exam(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      answerKey: answerKey,
    );
  }
}

class StudentEvaluation {
  const StudentEvaluation({
    this.id,
    required this.examId,
    required this.studentRoll,
    required this.score,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.blankCount,
    required this.createdAt,
  });

  final int? id;
  final int examId;
  final String studentRoll;
  final int score;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int blankCount;
  final DateTime createdAt;

  double get percentage =>
      totalQuestions == 0 ? 0.0 : (score / totalQuestions) * 100.0;

  factory StudentEvaluation.fromMap(Map<String, Object?> map) {
    return StudentEvaluation(
      id: map['id'] as int?,
      examId: (map['exam_id'] as num).toInt(),
      studentRoll: map['student_roll'] as String,
      score: (map['score'] as num).toInt(),
      totalQuestions: (map['total_questions'] as num).toInt(),
      correctCount: (map['correct_count'] as num).toInt(),
      wrongCount: (map['wrong_count'] as num).toInt(),
      blankCount: (map['blank_count'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'exam_id': examId,
      'student_roll': studentRoll,
      'score': score,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'blank_count': blankCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
