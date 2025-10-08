import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_status.dart';
import '../models/active_load.dart';
import '../models/hos_summary.dart';
import 'offline_storage_provider.dart';
import '../../connectivity/connectivity_provider.dart';

// Driver Status Provider with offline support
final driverStatusProvider = StreamProvider<DriverStatus?>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  final isOnline = ref.watch(connectivityStatusProvider);
  final offlineStorage = ref.watch(offlineStorageProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  if (!isOnline) {
    // Return cached data when offline
    return Stream.fromFuture(offlineStorage.getDriverStatus());
  }

  return supabase
      .from('driver_status')
      .stream(primaryKey: ['id'])
      .eq('driver_id', userId)
      .map((data) {
        if (data.isEmpty) return null;
        final status = DriverStatus.fromJson(data.first as Map<String, dynamic>);
        // Cache for offline use
        offlineStorage.saveDriverStatus(status);
        return status;
      });
});

// Active Load Provider with offline support
final activeLoadProvider = FutureProvider<ActiveLoad?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  final isOnline = ref.watch(connectivityStatusProvider);
  final offlineStorage = ref.watch(offlineStorageProvider);

  if (userId == null) return null;

  if (!isOnline) {
    return await offlineStorage.getActiveLoad();
  }

  try {
    final response = await supabase
        .from('loads')
        .select()
        .eq('driver_id', userId)
        .eq('status', 'in_transit')
        .maybeSingle();

    final load = response != null ? ActiveLoad.fromJson(response as Map<String, dynamic>) : null;
    // Cache for offline use
    await offlineStorage.saveActiveLoad(load);
    return load;
  } catch (_) {
    // If online fetch fails, try offline cache
    return await offlineStorage.getActiveLoad();
  }
});

// HOS Summary Provider with offline support
final hosSummaryProvider = FutureProvider<HOSSummary?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  final isOnline = ref.watch(connectivityStatusProvider);
  final offlineStorage = ref.watch(offlineStorageProvider);

  if (userId == null) return null;

  if (!isOnline) {
    return await offlineStorage.getHOSSummary();
  }

  try {
    final response = await supabase
        .from('hos_records')
        .select()
        .eq('driver_id', userId)
        .order('date', ascending: false)
        .limit(1)
        .maybeSingle();

    final hos = response != null ? HOSSummary.fromJson(response as Map<String, dynamic>) : null;
    if (hos != null) {
      await offlineStorage.saveHOSSummary(hos);
    }
    return hos;
  } catch (_) {
    return await offlineStorage.getHOSSummary();
  }
});

// Driver Loads with offline support
final driversLoadsProvider = StreamProvider<List<ActiveLoad>>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  final isOnline = ref.watch(connectivityStatusProvider);
  final offlineStorage = ref.watch(offlineStorageProvider);

  if (userId == null) {
    return Stream.value([]);
  }

  if (!isOnline) {
    return Stream.fromFuture(offlineStorage.getLoads());
  }

  return supabase
      .from('loads')
      .stream(primaryKey: ['id'])
      .eq('driver_id', userId)
      .order('created_at', ascending: false)
      .map((data) {
        final loads = data.map((json) => ActiveLoad.fromJson(json as Map<String, dynamic>)).toList();
        // Cache for offline use
        offlineStorage.saveLoads(loads);
        return loads;
      });
});

// Sync provider - syncs pending changes when back online
final syncProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

class SyncService {
  final Ref ref;

  SyncService(this.ref);

  Future<void> syncPendingChanges() async {
    final isOnline = ref.read(connectivityStatusProvider);
    if (!isOnline) return;

    final offlineStorage = ref.read(offlineStorageProvider);
    final pending = await offlineStorage.getPendingSync();

    if (pending.isEmpty) return;

    final supabase = Supabase.instance.client;

    for (final action in pending) {
      try {
        final type = action['type'] as String;
        final data = action['data'] as Map<String, dynamic>;

        switch (type) {
          case 'update_status':
            await supabase.from('driver_status').update(data).eq('driver_id', data['driver_id']);
            break;
          case 'update_location':
            await supabase.from('locations').insert(data);
            break;
          // Add more sync types as needed
        }
      } catch (e) {
        // Log sync error but continue with other items
        // ignore: avoid_print
        print('Sync error: $e');
      }
    }

    // Clear synced items
    await offlineStorage.clearPendingSync();
  }
}
