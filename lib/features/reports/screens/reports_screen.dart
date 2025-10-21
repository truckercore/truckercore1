import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_template.dart';
import '../providers/report_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportService = ref.watch(reportServiceProvider);
    final templates = reportService.getReportTemplates();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () => Navigator.pushNamed(context, '/reports/scheduled'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Stats',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStat('Reports Generated', '127', Icons.analytics),
                      ),
                      Expanded(
                        child: _buildQuickStat('Scheduled', '5', Icons.schedule),
                      ),
                      Expanded(
                        child: _buildQuickStat('This Month', '23', Icons.calendar_today),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Report Templates
          const Text(
            'Available Reports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...templates.map((template) => _buildReportCard(context, template)),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReportCard(BuildContext context, ReportTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(template.icon, color: Colors.blue),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(template.description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showReportDialog(context, template),
      ),
    );
  }

  void _showReportDialog(BuildContext context, ReportTemplate template) {
    showDialog(
      context: context,
      builder: (context) => _ReportGenerationDialog(template: template),
    );
  }
}

class _ReportGenerationDialog extends ConsumerStatefulWidget {
  final ReportTemplate template;

  const _ReportGenerationDialog({required this.template});

  @override
  ConsumerState<_ReportGenerationDialog> createState() => _ReportGenerationDialogState();
}

class _ReportGenerationDialogState extends ConsumerState<_ReportGenerationDialog> {
  final Map<String, dynamic> _parameters = {};
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.template.description,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ...widget.template.parameters.map((param) => _buildParameterInput(param)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : () => _generateReport(context),
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(_isGenerating ? 'Generating...' : 'Generate'),
        ),
      ],
    );
  }

  Widget _buildParameterInput(ReportParameter param) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            param.label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _buildInputField(param),
        ],
      ),
    );
  }

  Widget _buildInputField(ReportParameter param) {
    switch (param.type) {
      case ReportParameterType.dateRange:
        return OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _parameters[param.key] = {
                  'start': picked.start.toIso8601String(),
                  'end': picked.end.toIso8601String(),
                };
              });
            }
          },
          icon: const Icon(Icons.calendar_today),
          label: Text(
            _parameters[param.key] != null ? 'Date range selected' : 'Select date range',
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      case ReportParameterType.text:
        return TextField(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Enter ${param.label.toLowerCase()}',
          ),
          onChanged: (value) => _parameters[param.key] = value,
        );
      default:
        return TextField(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Select ${param.label.toLowerCase()}',
          ),
          readOnly: true,
        );
    }
  }

  Future<void> _generateReport(BuildContext context) async {
    // Validate required parameters
    for (final param in widget.template.parameters) {
      if (param.required && !_parameters.containsKey(param.key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${param.label} is required')),
        );
        return;
    }
    }

    setState(() => _isGenerating = true);

    try {
      final reportService = ref.read(reportServiceProvider);
      final result = await reportService.generateReport(
        type: widget.template.type,
        parameters: _parameters,
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          '/reports/view',
          arguments: result,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
