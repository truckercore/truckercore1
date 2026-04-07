import 'package:flutter_riverpod/flutter_riverpod.dart';

class HosLog {
  final String id;
  final String driverId;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final String status; // driving | on | rest | off
  const HosLog({
    required this.id,
    required this.driverId,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.status,
  });
}

abstract class HosApi {
  Future<List<HosLog>> get7DayLogs(String driverId);
}

class MockHosApi implements HosApi {
  @override
  Future<List<HosLog>> get7DayLogs(String driverId) async {
    final now = DateTime.now().toUtc();
    final day = const Duration(hours: 24);
    return [
      HosLog(
        id: 'log_${now.millisecondsSinceEpoch}',
        driverId: driverId,
        startTimeUtc: now.subtract(day * 1).subtract(const Duration(hours: 8)),
        endTimeUtc: now.subtract(day * 1),
        status: 'driving',
      ),
      HosLog(
        id: 'log_${now.millisecondsSinceEpoch - 1}',
        driverId: driverId,
        startTimeUtc: now.subtract(day * 2),
        endTimeUtc: now.subtract(day * 2).add(const Duration(hours: 8)),
        status: 'on',
      ),
    ];
  }
}

final hosApiProvider = Provider<HosApi>((ref) => MockHosApi());
