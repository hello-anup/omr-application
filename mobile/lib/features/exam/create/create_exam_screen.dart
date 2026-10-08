import 'package:flutter/material.dart';

import '../../../services/database/database_service.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createExam() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exam name.')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      await DatabaseService.instance.createExam(name: name);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create exam: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Exam')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create a new exam',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Give your exam a name to get started.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createExam(),
                      decoration: const InputDecoration(
                        labelText: 'Exam name',
                        hintText: 'e.g. Physics Midterm',
                        prefixIcon: Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isCreating ? null : _createExam,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_isCreating ? 'Creating...' : 'Create Exam'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
