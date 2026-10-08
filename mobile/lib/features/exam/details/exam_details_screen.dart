import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/database/database_service.dart';
import '../../../services/image_picker_service.dart';
import '../../../services/omr_api_service.dart';
import '../manual/manual_answer_key_screen.dart';
import '../../scanner/scanner_screen.dart';

class ExamDetailsScreen extends StatefulWidget {
  const ExamDetailsScreen({
    super.key,
    required this.examId,
    required this.examName,
  });

  final int examId;
  final String examName;

  @override
  State<ExamDetailsScreen> createState() => _ExamDetailsScreenState();
}

class _ExamDetailsScreenState extends State<ExamDetailsScreen> {
  static const _maxDetectedQuestions = 30;

  final _questionController = TextEditingController();
  Map<int, String?> _answerKey = {};
  bool _loadingKey = true;
  bool _isProcessingSolution = false;

  @override
  void initState() {
    super.initState();
    _loadAnswerKey();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadAnswerKey() async {
    final answerKey = await DatabaseService.instance.getAnswerKey(
      examId: widget.examId,
    );

    if (!mounted) return;

    setState(() {
      _answerKey = answerKey;
      _loadingKey = false;
    });

    if (answerKey.isNotEmpty && _questionController.text.trim().isEmpty) {
      _questionController.text = answerKey.length.toString();
    }
  }

  Future<void> _openManualInput() async {
    final count = int.tryParse(_questionController.text.trim());

    if (count == null || count <= 0 || count > _maxDetectedQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a question count from 1 to 30.')),
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManualAnswerKeyScreen(
          examId: widget.examId,
          examName: widget.examName,
          questionCount: count,
        ),
      ),
    );

    if (saved == true) {
      await _loadAnswerKey();
    }
  }

  Future<void> _scanSolutionSheet() async {
    final count = int.tryParse(_questionController.text.trim());

    if (count == null || count <= 0 || count > _maxDetectedQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a question count from 1 to 30 first.'),
        ),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Capture with Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final imagePickerService = ImagePickerService();
    final pickedFile = source == ImageSource.camera
        ? await imagePickerService.pickFromCamera()
        : await imagePickerService.pickFromGallery();

    if (pickedFile == null) return;

    setState(() => _isProcessingSolution = true);

    try {
      final omrApi = OmrApiService();
      final result = await omrApi.processImage(
        imagePath: pickedFile.path,
        imageName: pickedFile.name,
      );

      const banglaToEnglish = {'ক': 'A', 'খ': 'B', 'গ': 'C', 'ঘ': 'D'};

      final answers = <int, String?>{for (int i = 1; i <= count; i++) i: null};

      for (final answer in result.answers) {
        if (answer.questionNumber >= 1 && answer.questionNumber <= count) {
          final opt = answer.selectedOption?.trim();
          if (opt != null && opt.isNotEmpty && answer.status == 'marked') {
            final mapped = banglaToEnglish[opt] ?? opt.toUpperCase();
            if (const ['A', 'B', 'C', 'D'].contains(mapped)) {
              answers[answer.questionNumber] = mapped;
            }
          }
        }
      }

      await DatabaseService.instance.saveAnswerKey(
        examId: widget.examId,
        answers: answers,
      );

      if (!mounted) return;

      await _loadAnswerKey();

      if (!mounted) return;

      final detectedCount = answers.values.where((v) => v != null).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solution sheet processed: $detectedCount/$count answers detected and saved.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to detect answer key: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingSolution = false);
      }
    }
  }

  void _openEvaluation() {
    if (_answerKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save an answer key first.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          examId: widget.examId,
          examName: widget.examName,
          answerKey: _answerKey,
        ),
      ),
    );
  }

  String get _answerKeyStatus {
    if (_loadingKey) return 'Loading answer key...';
    if (_answerKey.isEmpty) return 'No answer key saved yet.';
    final filled = _answerKey.values.where((answer) => answer != null).length;
    return 'Saved answer key: $filled/${_answerKey.length} marked.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.examName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Answer Key Status'),
              subtitle: Text(_answerKeyStatus),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _questionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of questions',
              hintText: '1 to 30',
              prefixIcon: Icon(Icons.format_list_numbered),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Answer Key',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(
                _answerKey.isEmpty ? 'Manual Input' : 'Edit Manually',
              ),
              subtitle: const Text('Enter answers manually'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isProcessingSolution ? null : _openManualInput,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: _isProcessingSolution
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              title: const Text('Scan Solution Sheet'),
              subtitle: Text(
                _isProcessingSolution
                    ? 'Detecting answers...'
                    : 'Use camera or gallery',
              ),
              trailing: _isProcessingSolution
                  ? null
                  : const Icon(Icons.chevron_right),
              onTap: _isProcessingSolution ? null : _scanSolutionSheet,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Evaluation',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.people_outline,
                color: _answerKey.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              title: const Text('Evaluate Students'),
              subtitle: Text(
                _answerKey.isNotEmpty
                    ? 'Scan and grade student sheets'
                    : 'Save an answer key first to enable evaluation',
              ),
              trailing: _answerKey.isNotEmpty
                  ? const Icon(Icons.chevron_right)
                  : null,
              onTap: _answerKey.isNotEmpty ? _openEvaluation : null,
            ),
          ),
        ],
      ),
    );
  }
}
