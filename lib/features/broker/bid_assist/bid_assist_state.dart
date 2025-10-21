import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/telemetry/telemetry.dart';
import 'bid_assist_service.dart';

enum BidAssistStatus { idle, loading, loaded, error }

class BidAssistVM extends StateNotifier<BidAssistState> {
  final Ref _ref;
  BidAssistVM(this._ref) : super(BidAssistState.initial());

  Future<void> openAndFetch(BidAssistRequest req) async {
    Telemetry.event('bid_assist_opened', {
      'loadId': req.loadId,
      'origin': req.origin,
      'destination': req.destination,
      'equipment': req.equipment,
    });
    await recalc(req);
  }

  Future<void> recalc(BidAssistRequest req) async {
    state = state.copyWith(status: BidAssistStatus.loading);
    try {
      final res = await _ref.read(bidAssistServiceProvider).suggest(req);
      state = state.copyWith(
        status: BidAssistStatus.loaded,
        data: res,
        auditId: res.auditId,
      );
      Telemetry.event('bid_assist_result', {
        'auditId': res.auditId,
        'suggestedBidUsd': res.suggestedBidUsd,
        'p50Usd': res.band['p50Usd'],
        'p80Usd': res.band['p80Usd'],
        'feasible': res.feasibility['onTime'],
        'confidence': res.band['confidence'],
      });
    } catch (e) {
      final code = e.toString().contains('NO_COVERAGE') ? 'NO_COVERAGE' : 'ERROR';
      state = state.copyWith(status: BidAssistStatus.error, errorCode: code);
      if (code == 'NO_COVERAGE') {
        Telemetry.event('bid_assist_no_coverage', {
          'origin': req.origin,
          'destination': req.destination,
          'equipment': req.equipment,
        });
      }
    }
  }

  Future<void> apply(double value, {String? loadId}) async {
    final auditId = state.auditId;
    if (auditId == null) return;
    Telemetry.event('bid_assist_applied', {
      'auditId': auditId,
      'loadId': loadId,
      'acceptedBidUsd': value,
    });
    try {
      await _ref.read(bidAssistServiceProvider).logApply(auditId: auditId, loadId: loadId, acceptedBidUsd: value);
    } catch (_) {}
  }
}

class BidAssistState {
  final BidAssistStatus status;
  final BidAssistResult? data;
  final String? errorCode;
  final String? auditId;
  final double deadheadMiles;
  const BidAssistState({
    required this.status,
    required this.data,
    required this.errorCode,
    required this.auditId,
    required this.deadheadMiles,
  });
  factory BidAssistState.initial() => const BidAssistState(status: BidAssistStatus.idle, data: null, errorCode: null, auditId: null, deadheadMiles: 0);
  BidAssistState copyWith({BidAssistStatus? status, BidAssistResult? data, String? errorCode, String? auditId, double? deadheadMiles}) => BidAssistState(
    status: status ?? this.status,
    data: data ?? this.data,
    errorCode: errorCode ?? this.errorCode,
    auditId: auditId ?? this.auditId,
    deadheadMiles: deadheadMiles ?? this.deadheadMiles,
  );
}

final bidAssistProvider = StateNotifierProvider<BidAssistVM, BidAssistState>((ref) => BidAssistVM(ref));
