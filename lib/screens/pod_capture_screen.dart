import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../models/pod.dart';
import '../providers/pod_provider.dart';

class PODCaptureScreen extends ConsumerStatefulWidget {
  const PODCaptureScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PODCaptureScreen> createState() => _PODCaptureScreenState();
}

class _PODCaptureScreenState extends ConsumerState<PODCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loadNumberController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientTitleController = TextEditingController();
  final _notesController = TextEditingController();

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
  );

  final ImagePicker _picker = ImagePicker();
  List<XFile> _photos = [];
  Uint8List? _signatureImage;

  @override
  void dispose() {
    _loadNumberController.dispose();
    _recipientNameController.dispose();
    _recipientTitleController.dispose();
    _notesController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() => _photos.add(photo));
    }
  }

  Future<void> _pickPhotos() async {
    final List<XFile> photos = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (photos.isNotEmpty) {
      setState(() => _photos.addAll(photos));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _clearSignature() {
    _signatureController.clear();
    setState(() => _signatureImage = null);
  }

  Future<void> _captureSignature() async {
    final signature = await _signatureController.toPngBytes();
    setState(() {
      _signatureImage = signature;
    });
  }

  Future<void> _submitPOD() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_signatureImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture recipient signature'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture at least one delivery photo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final photos = _photos
        .asMap()
        .entries
        .map(
          (entry) => Photo(
            id: 'photo-${now.millisecondsSinceEpoch}-${entry.key}',
            url: entry.value.path,
            caption: 'Delivery Photo ${entry.key + 1}',
            timestamp: now.toIso8601String(),
          ),
        )
        .toList();

    final pod = POD(
      id: 'POD-${now.millisecondsSinceEpoch}',
      loadId: 'LOAD-${_loadNumberController.text}',
      loadNumber: _loadNumberController.text,
      deliveryDate: now.toIso8601String().split('T')[0],
      deliveryTime: now.toIso8601String().split('T')[1],
      recipientName: _recipientNameController.text,
      recipientTitle: _recipientTitleController.text.isEmpty
          ? null
          : _recipientTitleController.text,
      signature: 'data:image/png;base64,${_signatureImage.toString()}',
      photos: photos,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      location: const PODLocation(
        lat: 0.0,
        lng: 0.0,
        address: 'Current Location',
      ),
      createdAt: now.toIso8601String(),
      driverId: 'DRV-001',
      driverName: 'Current Driver',
    );

    try {
      await ref.read(podNotifierProvider.notifier).submitPOD(pod);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('POD submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _formKey.currentState!.reset();
        _loadNumberController.clear();
        _recipientNameController.clear();
        _recipientTitleController.clear();
        _notesController.clear();
        _clearSignature();
        setState(() => _photos.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POD Capture')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildBasicInfo(),
            const SizedBox(height: 16),
            _buildSignatureSection(),
            const SizedBox(height: 16),
            _buildPhotoSection(),
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delivery Time: ${DateTime.now().toString().substring(0, 16)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Information',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loadNumberController,
              decoration: const InputDecoration(
                labelText: 'Load Number',
                prefixIcon: Icon(Icons.local_shipping),
                hintText: 'LD-2025-XXX',
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Please enter load number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _recipientNameController,
              decoration: const InputDecoration(
                labelText: 'Recipient Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Please enter recipient name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _recipientTitleController,
              decoration: const InputDecoration(
                labelText: 'Recipient Title (Optional)',
                prefixIcon: Icon(Icons.badge),
                hintText: 'e.g., Warehouse Manager',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recipient Signature',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _clearSignature,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _captureSignature,
              icon: const Icon(Icons.check),
              label: const Text('Capture Signature'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Photos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('From Gallery'),
                  ),
                ),
              ],
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Photos (${_photos.length})',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _photos[index].path,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => const Icon(Icons.image, size: 48),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: InkWell(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Add any special notes about the delivery...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitPOD,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      child: const Text(
        'Submit Proof of Delivery',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
