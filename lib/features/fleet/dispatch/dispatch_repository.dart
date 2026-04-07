import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/config/app_config.dart';

class DispatchLoad {
  final String id;
  final String origin;
  final String destination;
  final DateTime pickup;
  final String? driverId;
  DispatchLoad({required this.id, required this.origin, required this.destination, required this.pickup, this.driverId});
  DispatchLoad copyWith({String? driverId}) => DispatchLoad(id: id, origin: origin, destination: destination, pickup: pickup, driverId: driverId ?? this.driverId);
}

abstract class DispatchRepository {
  Stream<List<DispatchLoad>> watchUnassignedLoads(Map<String, dynamic> filters);
  Stream<Map<String, List<DispatchLoad>>> watchAssignedLoads(Map<String, dynamic> filters); // driverId -> loads
  Future<void> assignDriver(String loadId, String driverId);
}

class MockDispatchRepository implements DispatchRepository {
  final _unassigned = StreamController<List<DispatchLoad>>.broadcast();
  final _assigned = StreamController<Map<String, List<DispatchLoad>>>.broadcast();
  final Map<String, DispatchLoad> _loads = {};

  MockDispatchRepository(){
    final now = DateTime.now();
    _loads['L1'] = DispatchLoad(id:'L1', origin:'DAL', destination:'ATL', pickup: now.add(const Duration(hours:4)));
    _loads['L2'] = DispatchLoad(id:'L2', origin:'HOU', destination:'MIA', pickup: now.add(const Duration(hours:6)));
    _loads['L3'] = DispatchLoad(id:'L3', origin:'OKC', destination:'ELP', pickup: now.add(const Duration(hours:8)));
    _emit();
  }
  void _emit(){
    final unassigned = _loads.values.where((l)=>l.driverId==null).toList()..sort((a,b)=>a.pickup.compareTo(b.pickup));
    final assigned = <String,List<DispatchLoad>>{};
    for(final l in _loads.values.where((l)=>l.driverId!=null)){
      assigned.putIfAbsent(l.driverId!, ()=>[]).add(l);
    }
    _unassigned.add(unassigned);
    _assigned.add(assigned);
  }
  @override
  Stream<List<DispatchLoad>> watchUnassignedLoads(Map<String, dynamic> filters) => _unassigned.stream;
  @override
  Stream<Map<String, List<DispatchLoad>>> watchAssignedLoads(Map<String, dynamic> filters) => _assigned.stream;
  @override
  Future<void> assignDriver(String loadId, String driverId) async {
    final l = _loads[loadId];
    if (l==null) return;
    _loads[loadId] = l.copyWith(driverId: driverId);
    _emit();
  }
}

final dispatchRepositoryProvider = Provider<DispatchRepository>((ref){
  ref.watch(appConfigProvider);
  return MockDispatchRepository();
});
