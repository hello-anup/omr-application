import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../services/database/database_service.dart';
import '../exam/create/create_exam_screen.dart';
import '../exam/details/exam_details_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _exams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    final exams = await DatabaseService.instance.getExams();

    if (!mounted) return;

    setState(() {
      _exams = exams;
      _loading = false;
    });
  }

  Future<void> _openCreateExam() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateExamScreen()));

    if (created == true) {
      await _loadExams();
    }
  }

  Future<void> _deleteExam(int examId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Exam'),
        content: const Text('Are you sure you want to delete this exam?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.deleteExam(examId);
      if (!mounted) return;
      await _loadExams();
    }
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) return value;

    final local = date.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${local.day}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.homeTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadExams,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HeroPanel(onCreateExam: _openCreateExam),
              const SizedBox(height: 28),
              Text(
                'Created Exams',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_exams.isEmpty)
                const _EmptyExams()
              else
                ..._exams.map(
                  (exam) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExamCard(
                      examId: (exam['id'] as num).toInt(),
                      name: exam['name'].toString(),
                      createdAt: _formatDate(exam['created_at'].toString()),
                      onDelete: () => _deleteExam((exam['id'] as num).toInt()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onCreateExam});

  final VoidCallback onCreateExam;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 44,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              'Create and evaluate exams',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an exam, add its answer key, then scan student answer sheets for evaluation.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateExam,
              icon: const Icon(Icons.add),
              label: const Text('Create Exam'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyExams extends StatelessWidget {
  const _EmptyExams();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No exams created yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first exam to get started.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.examId,
    required this.name,
    required this.createdAt,
    required this.onDelete,
  });

  final int examId;
  final String name;
  final String createdAt;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Created: $createdAt'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Exam',
              onPressed: onDelete,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExamDetailsScreen(examId: examId, examName: name),
            ),
          );
        },
      ),
    );
  }
}
