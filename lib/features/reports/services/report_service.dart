import 'package:flutter/material.dart';
import 'package:truckercore1/core/observability/performance_tracer.dart';

import '../../../services/supa_client.dart';
import '../models/report_template.dart';

class ReportService {
  /// Get available report templates
  List<ReportTemplate> getReportTemplates() {
    return [
      const ReportTemplate(
        type: ReportType.fleetPerformance,
        name: 'Fleet Performance',
        description: 'Overview of fleet operations, utilization, and metrics',
        icon: Icons.dashboard,
        parameters: [
          ReportParameter(
            key: 'date_range',
            label: 'Date Range',
            type: ReportParameterType.dateRange,
            required: true,
          ),
        ],
      ),
      const ReportTemplate(
        type: ReportType.driverPerformance,
        name: 'Driver Performance',
        description: 'Individual driver metrics, safety scores, and efficiency',
        icon: Icons.person,
        parameters: [
          ReportParameter(
            key: 'date_range',
            label: 'Date Range',
            type: ReportParameterType.dateRange,
            required: true,
          ),
          ReportParameter(
            key: 'driver_id',
            label: 'Driver',
            type: ReportParameterType.driverSelection,
          ),
        ],
      ),
      const ReportTemplate(
        type: ReportType.fuelConsumption,
        name: 'Fuel Analysis',
        description: 'Fuel consumption, costs, and efficiency metrics',
        icon: Icons.local_gas_station,
        parameters: [
          ReportParameter(
            key: 'date_range',
            label: 'Date Range',
            type: ReportParameterType.dateRange,
            required: true,
          ),
          ReportParameter(
            key: 'vehicle_id',
            label: 'Vehicle',
            type: ReportParameterType.vehicleSelection,
          ),
        ],
      ),
      const ReportTemplate(
        type: ReportType.maintenanceHistory,
        name: 'Maintenance Report',
        description: 'Maintenance records, costs, and upcoming service',
        icon: Icons.build,
        parameters: [
          ReportParameter(
            key: 'date_range',
            label: 'Date Range',
            type: ReportParameterType.dateRange,
            required: true,
          ),
          ReportParameter(
            key: 'vehicle_id',
            label: 'Vehicle',
            type: ReportParameterType.vehicleSelection,
          ),
        ],
      ),
      const ReportTemplate(
        type: ReportType.safetyAnalytics,
        name: 'Safety Analytics',
        description: 'Safety events, violations, and driver behavior analysis',
        icon: Icons.security,
        parameters: [
          ReportParameter(
            key: 'date_range',
            label: 'Date Range',
            type: ReportParameterType.dateRange,
            required: true,
          ),
        ],
      ),
      const ReportTemplate(
        type: ReportType.financialSummary,
        name: 'Financial Summary',
        description: 'Revenue, expenses, and profit/loss statement',
        icon: Icons.attach_money,
        parameters: [
          ReportParameter(
            key: 'date_range',
            label: 'Date Range',
            type: ReportParameterType.dateRange,
            required: true,
          ),
        ],
      ),
      const ReportTemplate(
        type: ReportType.complianceReport,
        name: 'Compliance Report',
        description: 'HOS violations, DVIR status, and regulatory compliance',
        icon: Icons.checklist,
        parameters: [
          ReportParameter(
            key: 'date_range',
            label: 'Date Range',
            type: ReportParameterType.dateRange,
            required: true,
          ),
        ],
      ),
      const ReportTemplate(
        type: ReportType.iftaReport,
        name: 'IFTA Report',
        description: 'International Fuel Tax Agreement mileage and fuel data',
        icon: Icons.local_gas_station,
        parameters: [
          ReportParameter(
            key: 'quarter',
            label: 'Quarter',
            type: ReportParameterType.dropdown,
            required: true,
          ),
          ReportParameter(
            key: 'year',
            label: 'Year',
            type: ReportParameterType.dropdown,
            required: true,
          ),
        ],
      ),
    ];
  }

  /// Generate report
  Future<ReportResult> generateReport({
    required ReportType type,
    required Map<String, dynamic> parameters,
  }) async {
    return PerformanceTracer.trace<ReportResult>(
      'report.generate',
      () async {
        final formatSpan = PerformanceTracer.startSpan(
          'report.format',
          data: {'type': type.toString()},
        );
        try {
          final response = await SupaClient.functions('generate-report', {
            'report_type': type.name,
            'parameters': parameters,
          });
          final result = ReportResult.fromJson(Map<String, dynamic>.from(response.data as Map));
          await PerformanceTracer.finish(formatSpan);
          return result;
        } catch (e) {
          await PerformanceTracer.finish(formatSpan);
          rethrow;
        }
      },
      description: 'Generate ${type.name} report',
      data: {'report_type': type.toString()},
    );
  }

  /// Export report to PDF
  Future<String> exportReportToPDF({
    required ReportType type,
    required Map<String, dynamic> parameters,
  }) async {
    final response = await SupaClient.functions('export-report', {
      'report_type': type.name,
      'parameters': parameters,
      'format': 'pdf',
    });

    final map = Map<String, dynamic>.from(response.data as Map);
    return map['download_url'] as String;
  }

  /// Export report to Excel
  Future<String> exportReportToExcel({
    required ReportType type,
    required Map<String, dynamic> parameters,
  }) async {
    final response = await SupaClient.functions('export-report', {
      'report_type': type.name,
      'parameters': parameters,
      'format': 'xlsx',
    });

    final map = Map<String, dynamic>.from(response.data as Map);
    return map['download_url'] as String;
  }

  /// Schedule recurring report
  Future<void> scheduleReport({
    required ReportType type,
    required Map<String, dynamic> parameters,
    required String frequency, // 'daily', 'weekly', 'monthly'
    required List<String> recipients,
  }) async {
    await PerformanceTracer.traceQuery(
      'INSERT INTO scheduled_reports (report_type, parameters, frequency, recipients, active) VALUES (...)',
      () async {
        await SupaClient.from('scheduled_reports').insert({
          'report_type': type.name,
          'parameters': parameters,
          'frequency': frequency,
          'recipients': recipients,
          'active': true,
        });
        return null;
      },
    );
  }

  /// Get scheduled reports
  Future<List<ScheduledReport>> getScheduledReports() async {
    return PerformanceTracer.traceQuery(
      'SELECT * FROM scheduled_reports WHERE active = true ORDER BY created_at DESC',
      () async {
        final response = await SupaClient.from('scheduled_reports')
            .select('*')
            .eq('active', true)
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((r) => ScheduledReport.fromJson(Map<String, dynamic>.from(r)))
            .toList();
        // Record count measurement
        try { PerformanceTracer.recordMeasurement('scheduled_report_count', list.length); } catch (_) {}
        return list;
      },
    );
  }
}

class ReportResult {
  final String reportId;
  final ReportType type;
  final Map<String, dynamic> data;
  final DateTime generatedAt;

  const ReportResult({
    required this.reportId,
    required this.type,
    required this.data,
    required this.generatedAt,
  });

  factory ReportResult.fromJson(Map<String, dynamic> json) => ReportResult(
        reportId: json['report_id'] as String,
        type: ReportType.values.firstWhere((e) => e.name == json['type']),
        data: Map<String, dynamic>.from(json['data'] as Map),
        generatedAt: DateTime.parse(json['generated_at'] as String),
      );
}

class ScheduledReport {
  final String id;
  final ReportType type;
  final String frequency;
  final List<String> recipients;
  final bool active;

  const ScheduledReport({
    required this.id,
    required this.type,
    required this.frequency,
    required this.recipients,
    required this.active,
  });

  factory ScheduledReport.fromJson(Map<String, dynamic> json) => ScheduledReport(
        id: json['id'] as String,
        type: ReportType.values.firstWhere((e) => e.name == json['report_type']),
        frequency: json['frequency'] as String,
        recipients: (json['recipients'] as List).map((e) => e.toString()).toList(),
        active: json['active'] as bool,
      );
}
