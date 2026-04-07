// lib/features/loads/dto/counters.dart
import 'package:meta/meta.dart';

@immutable
class LoadsCounters {
  final int activeLoads;
  final int boostsUsedThisMonth;
  const LoadsCounters({required this.activeLoads, required this.boostsUsedThisMonth});

  Map<String, dynamic> toJson() => {
    'activeLoads': activeLoads,
    'boostsUsedThisMonth': boostsUsedThisMonth,
  };

  static LoadsCounters fromJson(Map<String, dynamic> json) => LoadsCounters(
    activeLoads: (json['activeLoads'] as num?)?.toInt() ?? 0,
    boostsUsedThisMonth: (json['boostsUsedThisMonth'] as num?)?.toInt() ?? 0,
  );
}
