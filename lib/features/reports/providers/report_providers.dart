import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/report_service.dart';

// Global provider for ReportService
final reportServiceProvider = Provider<ReportService>((ref) => ReportService());
