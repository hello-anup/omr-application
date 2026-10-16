import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../services/database/database_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/omr_sheet_generator_service.dart';

class CustomOmrScreen extends StatefulWidget {
  const CustomOmrScreen({
    super.key,
    this.databaseService,
    this.imagePickerService,
    this.generatorService,
  });

  final DatabaseService? databaseService;
  final ImagePickerService? imagePickerService;
  final OmrSheetGeneratorService? generatorService;

  @override
  State<CustomOmrScreen> createState() => _CustomOmrScreenState();
}

class _CustomOmrScreenState extends State<CustomOmrScreen> {
  late final DatabaseService _db;
  late final ImagePickerService _picker;
  late final OmrSheetGeneratorService _generator;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  Uint8List? _logoBytes;
  String? _logoPath;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _db = widget.databaseService ?? DatabaseService.instance;
    _picker = widget.imagePickerService ?? ImagePickerService();
    _generator = widget.generatorService ?? OmrSheetGeneratorService.instance;
    _loadSavedProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfile() async {
    try {
      final profile = await _db.getInstitutionProfile();
      if (profile != null && mounted) {
        _nameController.text = profile['name']?.toString() ?? '';
        _addressController.text = profile['address']?.toString() ?? '';
        final path = profile['logo_path']?.toString();
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            _logoPath = path;
            _logoBytes = await file.readAsBytes();
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final file = await _picker.pickFromGallery();
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _logoBytes = bytes;
        _logoPath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select logo: $e')),
      );
    }
  }

  void _removeLogo() {
    setState(() {
      _logoBytes = null;
      _logoPath = null;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an institution name.')),
      );
      return;
    }

    try {
      await _db.saveInstitutionProfile(
        name: name,
        address: address,
        logoPath: _logoPath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Institution profile saved for future use!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  Future<void> _exportPdf() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an institution name.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Auto-save profile so user doesn't lose it
      await _db.saveInstitutionProfile(
        name: name,
        address: address,
        logoPath: _logoPath,
      );

      final pdfBytes = await _generator.generateCustomOmrPdf(
        institutionName: name,
        institutionAddress: address,
        logoBytes: _logoBytes,
      );

      final sanitizedName = name.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = 'omr_sheet_${sanitizedName}.pdf';

      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate OMR PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _previewAndPrint() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an institution name.')),
      );
      return;
    }

    try {
      await _db.saveInstitutionProfile(
        name: name,
        address: address,
        logoPath: _logoPath,
      );

      final pdfBytes = await _generator.generateCustomOmrPdf(
        institutionName: name,
        institutionAddress: address,
        logoBytes: _logoBytes,
      );

      final sanitizedName = name.replaceAll(RegExp(r'[^\w\s-]'), '_');
      await Printing.layoutPdf(
        name: 'omr_sheet_$sanitizedName',
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to preview/print: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom OMR Generator'),
        actions: [
          IconButton(
            tooltip: 'Save Profile',
            onPressed: _saveProfile,
            icon: const Icon(Icons.bookmark_added_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Information banner
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Custom Institution OMR Sheet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Generate official A4 OMR sheets with your institution name, address, and logo. Guaranteed 100% compatible with scanner!',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Institution Details Form
                  Text(
                    'Institution Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Institution Name *',
                      hintText: 'e.g. Dhaka Residential Model College',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Institution Address',
                      hintText: 'e.g. Mirpur Road, Mohammadpur, Dhaka',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Logo Card
                  Text(
                    'Institution Logo',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade100,
                            ),
                            alignment: Alignment.center,
                            child: _logoBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.memory(
                                      _logoBytes!,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : const Icon(Icons.image_outlined,
                                    size: 32, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _logoBytes != null
                                      ? 'Logo selected'
                                      : 'No logo selected (optional)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Appears in the header logo box of the sheet.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _pickLogo,
                                      icon: const Icon(
                                          Icons.photo_library_outlined,
                                          size: 16),
                                      label: Text(_logoBytes != null
                                          ? 'Change'
                                          : 'Pick Logo'),
                                    ),
                                    if (_logoBytes != null) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Remove Logo',
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: _removeLogo,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  FilledButton.icon(
                    onPressed: _isExporting ? null : _exportPdf,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('Export OMR Sheet (PDF)'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _previewAndPrint,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Preview & Print Directly'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Profile for Future Use'),
                  ),
                ],
              ),
            ),
    );
  }
}
