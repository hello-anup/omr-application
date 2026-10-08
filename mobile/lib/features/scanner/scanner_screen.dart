import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_picker_service.dart';
import '../processing/processing_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.examId,
    required this.examName,
    required this.answerKey,
  });

  final int examId;
  final String examName;
  final Map<int, String?> answerKey;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePickerService _imagePickerService = ImagePickerService();
  final _rollController = TextEditingController();

  XFile? _selectedImage;
  bool _isPicking = false;
  String? _statusMessage;

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Future<XFile?> Function() pickImage) async {
    setState(() {
      _isPicking = true;
      _statusMessage = null;
    });

    try {
      final image = await pickImage();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _statusMessage = image == null
            ? 'No image selected.'
            : 'Image selected. Ready to process.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _statusMessage =
            'Could not open image picker. Please check permission and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _openProcessingScreen() {
    final roll = _rollController.text.trim();
    if (roll.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the student roll number.')),
      );
      return;
    }

    final image = _selectedImage;
    if (image == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          imageName: image.name,
          imagePath: image.path,
          examId: widget.examId,
          studentRoll: roll,
          examName: widget.examName,
          answerKey: widget.answerKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Student Sheet')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.examName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Answer key loaded: ${widget.answerKey.length} questions',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _rollController,
              decoration: const InputDecoration(
                labelText: 'Student Roll Number',
                hintText: 'e.g. 101 or 2024-001',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            _PreviewPanel(selectedImage: _selectedImage),
            const SizedBox(height: 18),
            _PickerActions(
              isPicking: _isPicking,
              hasImage: _selectedImage != null,
              onCamera: () => _pickImage(_imagePickerService.pickFromCamera),
              onGallery: () => _pickImage(_imagePickerService.pickFromGallery),
              onContinue: _openProcessingScreen,
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 14),
              Text(_statusMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.selectedImage});

  final XFile? selectedImage;

  @override
  Widget build(BuildContext context) {
    final image = selectedImage;

    if (image == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 44,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Add a student OMR sheet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Capture a photo or choose an existing image for evaluation.',
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FutureBuilder<Uint8List>(
                future: image.readAsBytes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return Image.memory(
                    snapshot.data!,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              image.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerActions extends StatelessWidget {
  const _PickerActions({
    required this.isPicking,
    required this.hasImage,
    required this.onCamera,
    required this.onGallery,
    required this.onContinue,
  });

  final bool isPicking;
  final bool hasImage;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: isPicking ? null : onCamera,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(isPicking ? 'Opening picker...' : 'Capture with Camera'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isPicking ? null : onGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose Image from Gallery'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: hasImage ? onContinue : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue'),
        ),
      ],
    );
  }
}
