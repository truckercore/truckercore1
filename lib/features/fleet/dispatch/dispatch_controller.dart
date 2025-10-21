import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dispatch_repository.dart';

class DispatchState {
  final List<DispatchLoad> unassigned;
  final Map<String, List<DispatchLoad>> assigned;
  const DispatchState({required this.unassigned, required this.assigned});
}

class DispatchController extends StateNotifier<DispatchState> {
  DispatchController(this._ref): super(const DispatchState(unassigned: [], assigned: {})){
    _subUn = _repo.watchUnassignedLoads({}).listen((e)=> state = DispatchState(unassigned: e, assigned: state.assigned));
    _subAs = _repo.watchAssignedLoads({}).listen((e)=> state = DispatchState(unassigned: state.unassigned, assigned: e));
  }
  final Ref _ref;
  late final DispatchRepository _repo = _ref.read(dispatchRepositoryProvider);
  late final StreamSubscription _subUn;
  late final StreamSubscription _subAs;

  Future<void> assign(String loadId, String driverId) async {
    // optimistic: update state immediately
    final l = [...state.unassigned];
    final idx = l.indexWhere((x)=>x.id==loadId);
    if (idx>=0){
      final load = l.removeAt(idx).copyWith(driverId: driverId);
      final assigned = {...state.assigned};
      assigned.putIfAbsent(driverId, ()=>[]).add(load);
      state = DispatchState(unassigned: l, assigned: assigned);
    }
    try{
      await _repo.assignDriver(loadId, driverId);
    } catch (_) {
      // rollback simple: reload streams will correct
    }
  }

  @override
  void dispose(){
    _subUn.cancel();
    _subAs.cancel();
    super.dispose();
  }
}

final dispatchControllerProvider = StateNotifierProvider<DispatchController, DispatchState>((ref){
  return DispatchController(ref);
});
