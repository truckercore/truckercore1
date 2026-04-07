import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dvir.dart';
import '../services/dvir_service.dart';

class DVIRInspectionScreen extends ConsumerStatefulWidget {
  final String vehicleId;
  final String inspectionType; // 'pre_trip' or 'post_trip'

  const DVIRInspectionScreen({super.key, required this.vehicleId, required this.inspectionType});

  @override
  ConsumerState<DVIRInspectionScreen> createState() => _DVIRInspectionScreenState();
}

class _DVIRInspectionScreenState extends ConsumerState<DVIRInspectionScreen> {
  final Map<String, InspectionItem> _items = {};
  final TextEditingController _defectsController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _inspectionItems = const [
    'Brakes',
    'Tires',
    'Lights',
    'Mirrors',
    'Windshield',
    'Wipers',
    'Horn',
    'Steering',
    'Suspension',
    'Exhaust System',
    'Fuel System',
    'Coupling Devices',
    'Cargo Securement',
    'Emergency Equipment',
    'Air Lines & Electrical',
  ];

  @override
  void initState() {
    super.initState();
    for (final item in _inspectionItems) {
      _items[item] = InspectionItem(name: item, passed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPostTrip = widget.inspectionType == 'post_trip';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inspectionType == 'pre_trip' ? 'Pre-Trip Inspection' : 'Post-Trip Inspection'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            color: Colors.blue.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.inspectionType == 'pre_trip'
                              ? 'Complete before starting your trip'
                              : 'Complete at the end of your trip',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vehicle: ${widget.vehicleId}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Date: ${DateTime.now().toString().split(' ')[0]}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Odometer (for post-trip only)
          if (isPostTrip) ...[
            TextField(
              controller: _odometerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Odometer Reading',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Inspection Items
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Inspection Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ..._inspectionItems.map((item) => _buildInspectionTile(item)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Defects Notes
          TextField(
            controller: _defectsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Defects or Issues (if any)',
              border: OutlineInputBorder(),
              hintText: 'Describe any defects found...',
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitInspection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Inspection'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionTile(String item) {
    final inspectionItem = _items[item]!;
    final hasSeverity = !inspectionItem.passed;

    return ListTile(
      title: Text(item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSeverity)
            DropdownButton<String>(
              value: inspectionItem.severity ?? 'minor',
              items: const [
                DropdownMenuItem(value: 'minor', child: Text('Minor')),
                DropdownMenuItem(value: 'major', child: Text('Major')),
                DropdownMenuItem(value: 'critical', child: Text('Critical')),
              ],
              onChanged: (value) {
                setState(() {
                  _items[item] = InspectionItem(
                    name: item,
                    passed: false,
                    severity: value,
                    notes: inspectionItem.notes,
                  );
                });
              },
            ),
          const SizedBox(width: 8),
          Checkbox(
            value: inspectionItem.passed,
            onChanged: (value) {
              setState(() {
                _items[item] = InspectionItem(
                  name: item,
                  passed: value ?? true,
                  severity: value == true ? null : (inspectionItem.severity ?? 'minor'),
                  notes: inspectionItem.notes,
                );
              });
            },
          ),
        ],
      ),
      onTap: () {
        if (!inspectionItem.passed) {
          _showNotesDialog(item);
        }
      },
    );
  }

  void _showNotesDialog(String item) {
    final controller = TextEditingController(text: _items[item]!.notes);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notes for $item'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter notes about this issue...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final current = _items[item]!;
                _items[item] = InspectionItem(
                  name: item,
                  passed: current.passed,
                  severity: current.severity,
                  notes: controller.text,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitInspection() async {
    if (widget.inspectionType == 'post_trip' && _odometerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter odometer reading')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dvirService = ref.read(dvirServiceProvider);

      if (widget.inspectionType == 'pre_trip') {
        await dvirService.submitPreTripInspection(
          vehicleId: widget.vehicleId,
          items: _items,
          defectsNotes: _defectsController.text.isNotEmpty ? _defectsController.text : null,
        );
      } else {
        await dvirService.submitPostTripInspection(
          vehicleId: widget.vehicleId,
          items: _items,
          odometerReading: int.parse(_odometerController.text),
          defectsNotes: _defectsController.text.isNotEmpty ? _defectsController.text : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _defectsController.dispose();
    _odometerController.dispose();
    super.dispose();
  }
}
