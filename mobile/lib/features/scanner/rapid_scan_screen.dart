import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/database/database_service.dart';
import '../../services/evaluation_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/omr_api_service.dart';
import '../exam/results/exam_results_screen.dart';

enum QueueItemStatus { pending, processing, completed, failed }

class RapidScanItem {
  RapidScanItem({
    required this.id,
    required this.imageFile,
    required this.roll,
    this.status = QueueItemStatus.pending,
    this.score,
    this.totalQuestions,
    this.errorMessage,
  });

  final String id;
  final XFile imageFile;
  final String roll;
  QueueItemStatus status;
  int? score;
  int? totalQuestions;
  String? errorMessage;
}

class RapidScanScreen extends StatefulWidget {
  const RapidScanScreen({
    super.key,
    required this.examId,
    required this.examName,
    required this.answerKey,
    this.initialRoll = '101',
    this.imagePickerService,
    this.omrApiService,
  });

  final int examId;
  final String examName;
  final Map<int, String?> answerKey;
  final String initialRoll;
  final ImagePickerService? imagePickerService;
  final OmrApiService? omrApiService;

  static String incrementRoll(String currentRoll) {
    final match = RegExp(r'^(.*?)(\d+)$').firstMatch(currentRoll);
    if (match != null) {
      final prefix = match.group(1) ?? '';
      final digits = match.group(2)!;
      final nextNum = int.parse(digits) + 1;
      final padded = nextNum.toString().padLeft(digits.length, '0');
      return '$prefix$padded';
    }
    return '$currentRoll-1';
  }

  @override
  State<RapidScanScreen> createState() => _RapidScanScreenState();
}

class _RapidScanScreenState extends State<RapidScanScreen> {
  late final ImagePickerService _imagePickerService;
  late final OmrApiService _omrApiService;
  late final TextEditingController _rollController;

  final List<RapidScanItem> _queue = [];
  bool _isProcessingQueue = false;
  late String _nextRoll;

  @override
  void initState() {
    super.initState();
    _imagePickerService = widget.imagePickerService ?? ImagePickerService();
    _omrApiService = widget.omrApiService ?? OmrApiService();
    _nextRoll = widget.initialRoll;
    _rollController = TextEditingController(text: _nextRoll);
  }

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _captureCamera() async {
    final currentRoll = _rollController.text.trim().isEmpty
        ? _nextRoll
        : _rollController.text.trim();

    try {
      final image = await _imagePickerService.pickFromCamera();
      if (image == null) return;

      final newItem = RapidScanItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imageFile: image,
        roll: currentRoll,
      );

      final next = RapidScanScreen.incrementRoll(currentRoll);

      setState(() {
        _queue.add(newItem);
        _nextRoll = next;
        _rollController.text = next;
      });

      _startQueueProcessor();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open camera: $e')),
      );
    }
  }

  Future<void> _pickMultiGallery() async {
    final currentRoll = _rollController.text.trim().isEmpty
        ? _nextRoll
        : _rollController.text.trim();

    try {
      final images = await _imagePickerService.pickMultiFromGallery();
      if (images.isEmpty) return;

      var rollTracker = currentRoll;
      final newItems = <RapidScanItem>[];

      for (int i = 0; i < images.length; i++) {
        newItems.add(
          RapidScanItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_$i',
            imageFile: images[i],
            roll: rollTracker,
          ),
        );
        rollTracker = RapidScanScreen.incrementRoll(rollTracker);
      }

      setState(() {
        _queue.addAll(newItems);
        _nextRoll = rollTracker;
        _rollController.text = rollTracker;
      });

      _startQueueProcessor();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick gallery images: $e')),
      );
    }
  }

  Future<void> _startQueueProcessor() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (mounted) {
      final pendingIndex = _queue.indexWhere(
        (item) => item.status == QueueItemStatus.pending,
      );
      if (pendingIndex == -1) break;

      final item = _queue[pendingIndex];
      setState(() {
        item.status = QueueItemStatus.processing;
      });

      try {
        final omrResult = await _omrApiService.processImage(
          imagePath: item.imageFile.path,
          imageName: item.imageFile.name,
        );

        final eval = EvaluationService.instance.evaluate(
          answers: omrResult.answers,
          answerKey: widget.answerKey,
        );

        await DatabaseService.instance.saveStudentEvaluation(
          examId: widget.examId,
          studentRoll: item.roll,
          score: eval.score,
          totalQuestions: eval.totalQuestions,
          correctCount: eval.correctCount,
          wrongCount: eval.wrongCount,
          blankCount: eval.blankCount,
        );

        if (!mounted) break;
        setState(() {
          item.status = QueueItemStatus.completed;
          item.score = eval.score;
          item.totalQuestions = eval.totalQuestions;
        });
      } catch (e) {
        if (!mounted) break;
        setState(() {
          item.status = QueueItemStatus.failed;
          item.errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }

    _isProcessingQueue = false;
  }

  void _retryItem(RapidScanItem item) {
    setState(() {
      item.status = QueueItemStatus.pending;
      item.errorMessage = null;
    });
    _startQueueProcessor();
  }

  void _openResults() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamResultsScreen(
          examId: widget.examId,
          examName: widget.examName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount =
        _queue.where((i) => i.status == QueueItemStatus.completed).length;
    final failedCount =
        _queue.where((i) => i.status == QueueItemStatus.failed).length;
    final inProgressCount = _queue
        .where((i) =>
            i.status == QueueItemStatus.processing ||
            i.status == QueueItemStatus.pending)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapid Scan'),
        actions: [
          IconButton(
            tooltip: 'View Results',
            onPressed: _openResults,
            icon: const Icon(Icons.assessment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Config Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.amber, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.examName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rollController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Next Student Roll Number',
                        hintText: 'e.g. 101',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        _nextRoll = val;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Roll increments automatically by +1 after each image is added.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _captureCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Snap Photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMultiGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Gallery'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Progress Badges
          if (_queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _StatusChip(
                    label: 'Done',
                    count: completedCount,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Queue',
                    count: inProgressCount,
                    color: Colors.blue,
                  ),
                  if (failedCount > 0) ...[
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'Failed',
                      count: failedCount,
                      color: Colors.red,
                    ),
                  ],
                  const Spacer(),
                  if (_isProcessingQueue)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Evaluating...',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Queue List
          Expanded(
            child: _queue.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.speed_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Rapid Scan Ready',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Click photos continuously or select multiple images from gallery. Evaluation runs in the background and saves automatically!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _queue.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _queue[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusBgColor(item.status),
                            foregroundColor: _statusFgColor(item.status),
                            child: _statusIcon(item.status),
                          ),
                          title: Text(
                            'Roll: ${item.roll}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            item.status == QueueItemStatus.completed
                                ? 'Score: ${item.score}/${item.totalQuestions} (Saved to SQLite)'
                                : item.status == QueueItemStatus.processing
                                    ? 'Processing via OMR backend...'
                                    : item.status == QueueItemStatus.failed
                                        ? 'Error: ${item.errorMessage ?? 'Evaluation failed'}'
                                        : 'Waiting in queue...',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.status == QueueItemStatus.failed
                                  ? Colors.red
                                  : item.status == QueueItemStatus.completed
                                      ? Colors.green.shade800
                                      : Colors.grey.shade700,
                            ),
                          ),
                          trailing: item.status == QueueItemStatus.failed
                              ? IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.red),
                                  tooltip: 'Retry',
                                  onPressed: () => _retryItem(item),
                                )
                              : item.status == QueueItemStatus.completed
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openResults,
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('View All Results & Rankings'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusBgColor(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
        return Colors.grey.shade200;
      case QueueItemStatus.processing:
        return Colors.blue.shade100;
      case QueueItemStatus.completed:
        return Colors.green.shade100;
      case QueueItemStatus.failed:
        return Colors.red.shade100;
    }
  }

  Color _statusFgColor(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
        return Colors.grey.shade700;
      case QueueItemStatus.processing:
        return Colors.blue.shade900;
      case QueueItemStatus.completed:
        return Colors.green.shade900;
      case QueueItemStatus.failed:
        return Colors.red.shade900;
    }
  }

  Widget _statusIcon(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
        return const Icon(Icons.hourglass_empty, size: 20);
      case QueueItemStatus.processing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case QueueItemStatus.completed:
        return const Icon(Icons.check, size: 20);
      case QueueItemStatus.failed:
        return const Icon(Icons.close, size: 20);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}
