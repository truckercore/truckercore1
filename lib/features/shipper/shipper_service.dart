import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/state/phase3_flags.dart';
import '../pricing/market_rates_service.dart';

class ShipperLoad {
  final String id;
  final String originZip;
  final String destZip;
  final String equipment;
  final DateTime pickupDate;
  final DateTime deliveryDate;
  final int offeredCents;
  final String status; // open|assigned|cancelled
  const ShipperLoad({
    required this.id,
    required this.originZip,
    required this.destZip,
    required this.equipment,
    required this.pickupDate,
    required this.deliveryDate,
    required this.offeredCents,
    required this.status,
  });
}

class _MemStore {
  final List<ShipperLoad> loads = <ShipperLoad>[];
}

final _shipperMemStore = Provider<_MemStore>((_) => _MemStore());

class ShipperService {
  ShipperService(this._ref);
  final Ref _ref;

  Future<ShipperLoad> createLoad({
    required String originZip,
    required String destZip,
    required String equipment,
    required DateTime pickupDate,
    required DateTime deliveryDate,
    required int offeredCents,
  }) async {
    final flags = _ref.read(phase3FlagsProvider);
    // mock only: store in-memory
    if (flags.mock) {
      final id =
          'sl_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      final l = ShipperLoad(
        id: id,
        originZip: originZip,
        destZip: destZip,
        equipment: equipment,
        pickupDate: pickupDate,
        deliveryDate: deliveryDate,
        offeredCents: offeredCents,
        status: 'open',
      );
      _ref.read(_shipperMemStore).loads.insert(0, l);
      return l;
    }
    // live path: to be implemented later (insert into public.shipper_loads)
    final id = 'sl_demo_${DateTime.now().millisecondsSinceEpoch}';
    return ShipperLoad(
      id: id,
      originZip: originZip,
      destZip: destZip,
      equipment: equipment,
      pickupDate: pickupDate,
      deliveryDate: deliveryDate,
      offeredCents: offeredCents,
      status: 'open',
    );
  }

  Future<List<ShipperLoad>> listMyLoads() async {
    final flags = _ref.read(phase3FlagsProvider);
    if (flags.mock) {
      return List<ShipperLoad>.from(_ref.read(_shipperMemStore).loads);
    }
    return List<ShipperLoad>.from(
      _ref.read(_shipperMemStore).loads,
    ); // demo fallback
  }

  Future<LaneRateSeries> marketRates({
    required String originZip,
    required String destZip,
  }) async {
    final rates = _ref.read(marketRatesServiceProvider);
    return rates.getLaneRates(
      originZip: originZip,
      destZip: destZip,
    );
  }
}

final shipperServiceProvider = Provider<ShipperService>(
  (ref) => ShipperService(ref),
);
