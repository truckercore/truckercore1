import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// MVP safety record per driver (replace with Supabase rows later)
class SafetyRecord {
  final String driverUserId;
  final int trips;
  final int harshBrakes; // count / week
  final int overspeedMinutes; // minutes / week
  final int longDriveHours; // continuous hours without adequate rest
  final int score; // 0..100 higher = better
  final String grade; // A..F
  final List<String> flags; // human-readable notes

  const SafetyRecord({
    required this.driverUserId,
    required this.trips,
    required this.harshBrakes,
    required this.overspeedMinutes,
    required this.longDriveHours,
    required this.score,
    required this.grade,
    required this.flags,
  });
}

class SafetyService {
  const SafetyService(this._ref);
  // ignore: unused_field
  final Ref _ref;

  // MVP: random-but-stable mock based on driver id; replace with real query later
  Future<List<SafetyRecord>> listDriverSafety() async {
    final drivers = <String>[
      '00000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000004',
    ];

    final items = <SafetyRecord>[];
    for (final d in drivers) {
      final r = _mockFor(d);
      items.add(r);
    }
    // Sort risky first (lowest score first)
    items.sort((a, b) => a.score.compareTo(b.score));
    return items;
  }

  SafetyRecord _mockFor(String driverId) {
    final rng = Random(driverId.hashCode);
    final trips = 15 + rng.nextInt(15);
    final harsh = rng.nextInt(12); // 0..11
    final overspeed = rng.nextInt(90); // minutes
    final longDrive = rng.nextInt(5); // 0..4 hours
    // Start from 100 and subtract penalties
    int score = 100 - harsh * 3 - (overspeed ~/ 3) - longDrive * 5;
    if (score < 0) score = 0;

    final grade = _grade(score);
    final flags = <String>[];
    if (harsh >= 8) flags.add('Harsh braking often');
    if (overspeed >= 60) flags.add('Frequent speeding');
    if (longDrive >= 3) flags.add('Fatigue risk');

    if (flags.isEmpty) flags.add('Safe driving pattern');

    return SafetyRecord(
      driverUserId: driverId,
      trips: trips,
      harshBrakes: harsh,
      overspeedMinutes: overspeed,
      longDriveHours: longDrive,
      score: score,
      grade: grade,
      flags: flags,
    );
  }

  String _grade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}

final safetyServiceProvider = Provider<SafetyService>(
  (ref) => SafetyService(ref),
);
