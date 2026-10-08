import 'package:flutter/material.dart';

import '../../../services/database/database_service.dart';

class ManualAnswerKeyScreen extends StatefulWidget {
  const ManualAnswerKeyScreen({
    super.key,
    required this.examId,
    required this.examName,
    required this.questionCount,
  });

  final int examId;
  final String examName;
  final int questionCount;

  @override
  State<ManualAnswerKeyScreen> createState() => _ManualAnswerKeyScreenState();
}

class _ManualAnswerKeyScreenState extends State<ManualAnswerKeyScreen> {
  final Map<int, String?> _answers = {};

  bool _saving = false;
  bool _loading = true;

  static const options = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _loadAnswerKey();
  }

  Future<void> _loadAnswerKey() async {
    try {
      final savedAnswers = await DatabaseService.instance.getAnswerKey(
        examId: widget.examId,
      );

      if (!mounted) return;

      setState(() {
        _answers
          ..clear()
          ..addAll(savedAnswers);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load answer key: $error')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await DatabaseService.instance.saveAnswerKey(
        examId: widget.examId,
        answers: {
          for (int i = 1; i <= widget.questionCount; i++) i: _answers[i],
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer key saved successfully.')),
      );

      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Answer Key')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.examName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${widget.questionCount} questions - Select Blank if no correct answer is given.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: widget.questionCount,
                    itemBuilder: (context, index) {
                      final question = index + 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question $question',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ...options.map(
                                    (option) => ChoiceChip(
                                      label: Text(option),
                                      selected: _answers[question] == option,
                                      onSelected: (_) {
                                        setState(() {
                                          _answers[question] = option;
                                        });
                                      },
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Blank'),
                                    selected: _answers[question] == null,
                                    onSelected: (_) {
                                      setState(() {
                                        _answers[question] = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Answer Key'),
              ),
            ),
    );
  }
}
