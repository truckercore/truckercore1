// lib/features/profitability/services/profit_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/services/loads_service.dart';

class LoadProfitRow {
  final String id;
  final String origin;
  final String destination;
  final DateTime pickupAt;
  final DateTime dropoffAt;
  final int revenueCents;
  final int fuelCents;
  final int tollsCents;
  final int maintenanceCents;
  final int wageCents;

  int get costCents => fuelCents + tollsCents + maintenanceCents + wageCents;
  int get profitCents => revenueCents - costCents;
  double get marginPct =>
      revenueCents == 0 ? 0 : (profitCents / revenueCents) * 100.0;
  bool get unprofitable => profitCents < 0;

  const LoadProfitRow({
    required this.id,
    required this.origin,
    required this.destination,
    required this.pickupAt,
    required this.dropoffAt,
    required this.revenueCents,
    required this.fuelCents,
    required this.tollsCents,
    required this.maintenanceCents,
    required this.wageCents,
  });
}

class ProfitService {
  ProfitService(this._ref);
  final Ref _ref;

  Future<List<LoadProfitRow>> listProfitRows() async {
    // Reuse LoadsService to get base loads, then top-up by fetching each (or
    // add a LoadsService method that selects financial columns in one query).
    final loadsSvc = _ref.read(loadsServiceProvider);
    final list = await loadsSvc
        .listLoads(); // selects '*' so financials are included if present
    final out = <LoadProfitRow>[];
    for (final full in list) {
      out.add(
        LoadProfitRow(
          id: full.id,
          origin: full.origin,
          destination: full.destination,
          pickupAt: full.pickupAt,
          dropoffAt: full.dropoffAt,
          revenueCents: full.revenueCents,
          fuelCents: full.fuelCents,
          tollsCents: full.tollsCents,
          maintenanceCents: full.maintenanceCents,
          wageCents: full.wageCents,
        ),
      );
    }
    // Sort by most negative margin first (highlight problems)
    out.sort((a, b) => a.marginPct.compareTo(b.marginPct));
    return out;
  }
}

final profitServiceProvider = Provider<ProfitService>(
  (ref) => ProfitService(ref),
);
