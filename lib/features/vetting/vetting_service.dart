import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';
import '../../common/state/phase3_flags.dart';

class CarrierVetting {
  final String dotNumber;
  final String? mcNumber;
  final DateTime? insuranceExpiry;
  final String? safetyRating; // satisfactory | conditional | unsatisfactory
  final bool fraudFlag;
  final DateTime lastVerifiedAt;
  const CarrierVetting({
    required this.dotNumber,
    this.mcNumber,
    this.insuranceExpiry,
    this.safetyRating,
    required this.fraudFlag,
    required this.lastVerifiedAt,
  });
  Color get statusColor {
    if (fraudFlag || safetyRating == 'unsatisfactory') return Colors.redAccent;
    final expSoon =
        insuranceExpiry != null &&
        insuranceExpiry!.difference(DateTime.now()).inDays <= 14;
    if (safetyRating == 'conditional' || expSoon) return Colors.amber;
    return Colors.greenAccent;
  }
}

class VettingService {
  VettingService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<CarrierVetting> getCarrierByDot(String dot) async {
    final flags = _ref.read(phase3FlagsProvider);
    if (flags.mock) {
      return _mock(dot);
    }
    final c = _maybe();
    if (c == null) return _mock(dot);
    final row = await c
        .from('carrier_verifications')
        .select(
          'mc_number, insurance_expiry, safety_rating, fraud_flag, last_verified_at',
        )
        .eq('dot_number', dot)
        .maybeSingle();
    if (row == null) return _mock(dot);
    final m = Map<String, dynamic>.from(row as Map);
    return CarrierVetting(
      dotNumber: dot,
      mcNumber: m['mc_number'] as String?,
      insuranceExpiry: m['insurance_expiry'] != null
          ? DateTime.tryParse(m['insurance_expiry'] as String)
          : null,
      safetyRating: m['safety_rating'] as String?,
      fraudFlag: (m['fraud_flag'] as bool?) ?? false,
      lastVerifiedAt:
          DateTime.tryParse(m['last_verified_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Future<CarrierVetting> check({required String dotNumber}) async {
    // Mock is same as get; live would trigger an external verification and upsert.
    return getCarrierByDot(dotNumber);
  }

  CarrierVetting _mock(String dot) {
    final last = dot.isNotEmpty ? dot[dot.length - 1] : '1';
    if (last == '1') {
      return CarrierVetting(
        dotNumber: dot,
        mcNumber: 'MC12345',
        insuranceExpiry: DateTime.now().add(const Duration(days: 120)),
        safetyRating: 'satisfactory',
        fraudFlag: false,
        lastVerifiedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
    } else if (last == '2') {
      return CarrierVetting(
        dotNumber: dot,
        mcNumber: 'MC67890',
        insuranceExpiry: DateTime.now().add(const Duration(days: 7)),
        safetyRating: 'conditional',
        fraudFlag: false,
        lastVerifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
    } else if (last == '3') {
      return CarrierVetting(
        dotNumber: dot,
        mcNumber: 'MC24680',
        insuranceExpiry: DateTime.now().add(const Duration(days: 200)),
        safetyRating: 'unsatisfactory',
        fraudFlag: true,
        lastVerifiedAt: DateTime.now().subtract(const Duration(days: 3)),
      );
    }
    // default neutral
    return CarrierVetting(
      dotNumber: dot,
      mcNumber: 'MC00000',
      insuranceExpiry: DateTime.now().add(const Duration(days: 45)),
      safetyRating: 'satisfactory',
      fraudFlag: false,
      lastVerifiedAt: DateTime.now().subtract(const Duration(hours: 6)),
    );
  }
}

final vettingServiceProvider = Provider<VettingService>(
  (ref) => VettingService(ref),
);
