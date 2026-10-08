import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'omr_checker.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exams (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE answer_keys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id INTEGER NOT NULL,
            question_number INTEGER NOT NULL,
            answer TEXT,
            FOREIGN KEY (exam_id) REFERENCES exams(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE student_evaluations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id INTEGER NOT NULL,
            student_roll TEXT NOT NULL,
            score INTEGER NOT NULL,
            total_questions INTEGER NOT NULL,
            correct_count INTEGER NOT NULL,
            wrong_count INTEGER NOT NULL,
            blank_count INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (exam_id) REFERENCES exams(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE answer_keys (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              exam_id INTEGER NOT NULL,
              question_number INTEGER NOT NULL,
              answer TEXT,
              FOREIGN KEY (exam_id) REFERENCES exams(id)
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE student_evaluations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              exam_id INTEGER NOT NULL,
              student_roll TEXT NOT NULL,
              score INTEGER NOT NULL,
              total_questions INTEGER NOT NULL,
              correct_count INTEGER NOT NULL,
              wrong_count INTEGER NOT NULL,
              blank_count INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (exam_id) REFERENCES exams(id)
            )
          ''');
        }
      },
    );
  }

  Future<int> createExam({required String name}) async {
    final db = await database;

    return db.insert('exams', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getExams() async {
    late final Database db;

    try {
      db = await database;
    } on StateError catch (error) {
      if (error.message.contains('databaseFactory not initialized')) {
        return [];
      }
      rethrow;
    }

    return db.query('exams', orderBy: 'created_at DESC');
  }

  Future<Map<int, String?>> getAnswerKey({required int examId}) async {
    late final Database db;

    try {
      db = await database;
    } on StateError catch (error) {
      if (error.message.contains('databaseFactory not initialized')) {
        return {};
      }
      rethrow;
    }

    final rows = await db.query(
      'answer_keys',
      where: 'exam_id = ?',
      whereArgs: [examId],
      orderBy: 'question_number ASC',
    );

    return {
      for (final row in rows)
        (row['question_number'] as num).toInt(): row['answer'] as String?,
    };
  }

  Future<void> saveAnswerKey({
    required int examId,
    required Map<int, String?> answers,
  }) async {
    late final Database db;

    try {
      db = await database;
    } on StateError catch (error) {
      if (error.message.contains('databaseFactory not initialized')) {
        return;
      }
      rethrow;
    }

    await db.transaction((txn) async {
      await txn.delete(
        'answer_keys',
        where: 'exam_id = ?',
        whereArgs: [examId],
      );

      for (final entry in answers.entries) {
        await txn.insert('answer_keys', {
          'exam_id': examId,
          'question_number': entry.key,
          'answer': entry.value,
        });
      }
    });
  }

  Future<int> saveStudentEvaluation({
    required int examId,
    required String studentRoll,
    required int score,
    required int totalQuestions,
    required int correctCount,
    required int wrongCount,
    required int blankCount,
  }) async {
    late final Database db;

    try {
      db = await database;
    } on StateError catch (error) {
      if (error.message.contains('databaseFactory not initialized')) {
        return 0;
      }
      rethrow;
    }

    return db.insert('student_evaluations', {
      'exam_id': examId,
      'student_roll': studentRoll,
      'score': score,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'blank_count': blankCount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getStudentEvaluations({
    required int examId,
  }) async {
    late final Database db;

    try {
      db = await database;
    } on StateError catch (error) {
      if (error.message.contains('databaseFactory not initialized')) {
        return [];
      }
      rethrow;
    }

    return db.query(
      'student_evaluations',
      where: 'exam_id = ?',
      whereArgs: [examId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteExam(int examId) async {
    late final Database db;

    try {
      db = await database;
    } on StateError catch (error) {
      if (error.message.contains('databaseFactory not initialized')) {
        return;
      }
      rethrow;
    }

    await db.transaction((txn) async {
      await txn.delete(
        'student_evaluations',
        where: 'exam_id = ?',
        whereArgs: [examId],
      );
      await txn.delete(
        'answer_keys',
        where: 'exam_id = ?',
        whereArgs: [examId],
      );
      await txn.delete('exams', where: 'id = ?', whereArgs: [examId]);
    });
  }
}
