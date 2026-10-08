import 'package:flutter/material.dart';

import '../../services/omr_api_service.dart';
import '../result/result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.imageName,
    required this.imagePath,
    this.examId,
    this.studentRoll,
    this.examName,
    this.answerKey = const {},
  });

  final String imageName;
  final String imagePath;
  final int? examId;
  final String? studentRoll;
  final String? examName;
  final Map<int, String?> answerKey;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final OmrApiService _api = OmrApiService();
  bool _isProcessing = false;
  String? _error;

  Future<void> _runDetection() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result = await _api.processImage(
        imagePath: widget.imagePath,
        imageName: widget.imageName,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            examId: widget.examId,
            studentRoll: widget.studentRoll,
            examName: widget.examName,
            answerKey: widget.answerKey,
          ),
        ),
      );
    } on OmrApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Process OMR Sheet')),
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
                      Icons.auto_fix_high_outlined,
                      size: 42,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Image ready for processing',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.examName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.examName!,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (widget.studentRoll != null &&
                        widget.studentRoll!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Student Roll: ${widget.studentRoll}',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      widget.imageName,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _ProcessingStep(
              icon: Icons.crop_free_outlined,
              title: 'Sheet alignment',
              description: 'Find the paper boundary and straighten the image.',
            ),
            const SizedBox(height: 10),
            const _ProcessingStep(
              icon: Icons.radio_button_checked,
              title: 'Bubble detection',
              description: 'Locate answer bubbles and read selected marks.',
            ),
            const SizedBox(height: 10),
            const _ProcessingStep(
              icon: Icons.fact_check_outlined,
              title: 'Result preparation',
              description: 'Compare detected answers with the saved key.',
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _isProcessing ? null : _runDetection,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_outlined),
              label: Text(_isProcessing ? 'Processing...' : 'Run Detection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
