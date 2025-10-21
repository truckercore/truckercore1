import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OwnerOpFreeCapsState {
  final String monthKey; // e.g., 2025-08
  final int loadsAcceptedThisMonth;
  final String weekKey; // e.g., 2025-W35
  final int roaddoggUsesThisWeek;

  const OwnerOpFreeCapsState({
    required this.monthKey,
    required this.loadsAcceptedThisMonth,
    required this.weekKey,
    required this.roaddoggUsesThisWeek,
  });

  OwnerOpFreeCapsState copyWith({
    String? monthKey,
    int? loadsAcceptedThisMonth,
    String? weekKey,
    int? roaddoggUsesThisWeek,
  }) => OwnerOpFreeCapsState(
    monthKey: monthKey ?? this.monthKey,
    loadsAcceptedThisMonth:
        loadsAcceptedThisMonth ?? this.loadsAcceptedThisMonth,
    weekKey: weekKey ?? this.weekKey,
    roaddoggUsesThisWeek: roaddoggUsesThisWeek ?? this.roaddoggUsesThisWeek,
  );
}

class OwnerOpFreeCapsController extends StateNotifier<OwnerOpFreeCapsState> {
  static int? _safeExtractDigits(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(0)!);
  }

  static String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
  static String _weekKey(DateTime d) {
    final wStr = DateFormat('w').format(d);
    final weekOfYear = int.tryParse(wStr) ?? _safeExtractDigits(wStr) ?? 0;
    return '${d.year}-W${weekOfYear.toString().padLeft(2, '0')}';
  }

  final int freeLoadsPerMonth;
  final int freeRoadDoggPerWeek;

  OwnerOpFreeCapsController({
    this.freeLoadsPerMonth = 3,
    this.freeRoadDoggPerWeek = 3,
  }) : super(
         OwnerOpFreeCapsState(
           monthKey: _monthKey(DateTime.now().toUtc()),
           loadsAcceptedThisMonth: 0,
           weekKey: _weekKey(DateTime.now().toUtc()),
           roaddoggUsesThisWeek: 0,
         ),
       );

  void _rolloverIfNeeded() {
    final now = DateTime.now().toUtc();
    final m = _monthKey(now);
    final w = _weekKey(now);
    if (m != state.monthKey) {
      state = state.copyWith(monthKey: m, loadsAcceptedThisMonth: 0);
    }
    if (w != state.weekKey) {
      state = state.copyWith(weekKey: w, roaddoggUsesThisWeek: 0);
    }
  }

  int remainingLoads() {
    _rolloverIfNeeded();
    return (freeLoadsPerMonth - state.loadsAcceptedThisMonth).clamp(
      0,
      freeLoadsPerMonth,
    );
  }

  bool canAcceptLoad({required bool isPremium}) {
    if (isPremium) return true;
    _rolloverIfNeeded();
    return state.loadsAcceptedThisMonth < freeLoadsPerMonth;
  }

  void recordLoadAccepted() {
    _rolloverIfNeeded();
    state = state.copyWith(
      loadsAcceptedThisMonth: state.loadsAcceptedThisMonth + 1,
    );
  }

  int remainingRoadDoggUses() {
    _rolloverIfNeeded();
    return (freeRoadDoggPerWeek - state.roaddoggUsesThisWeek).clamp(
      0,
      freeRoadDoggPerWeek,
    );
  }

  bool canUseRoadDogg({required bool isPremium}) {
    if (isPremium) return true;
    _rolloverIfNeeded();
    return state.roaddoggUsesThisWeek < freeRoadDoggPerWeek;
  }

  void recordRoadDoggUse() {
    _rolloverIfNeeded();
    state = state.copyWith(
      roaddoggUsesThisWeek: state.roaddoggUsesThisWeek + 1,
    );
  }
}

final ownerOpFreeCapsProvider =
    StateNotifierProvider<OwnerOpFreeCapsController, OwnerOpFreeCapsState>((
      ref,
    ) {
      return OwnerOpFreeCapsController();
    });
