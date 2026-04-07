import 'package:flutter/material.dart';

enum ReportType {
  fleetPerformance,
  driverPerformance,
  fuelConsumption,
  maintenanceHistory,
  safetyAnalytics,
  financialSummary,
  complianceReport,
  utilizationReport,
  iftaReport,
}

class ReportTemplate {
  final ReportType type;
  final String name;
  final String description;
  final IconData icon;
  final List<ReportParameter> parameters;

  const ReportTemplate({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.parameters,
  });
}

class ReportParameter {
  final String key;
  final String label;
  final ReportParameterType type;
  final bool required;
  final dynamic defaultValue;

  const ReportParameter({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.defaultValue,
  });
}

enum ReportParameterType {
  dateRange,
  vehicleSelection,
  driverSelection,
  dropdown,
  text,
}
