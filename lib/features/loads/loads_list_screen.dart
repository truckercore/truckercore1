import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../common/services/event_logger.dart';
import '../../common/services/loads_service.dart';
import '../../common/state/session_provider.dart';
import '../../common/utils/retry.dart';
import '../../core/formatters/time_format.dart';
import '../../services/filters_service.dart';
import '../../services/supa_client.dart';
import '../broker/bid_assist/bid_assist_panel.dart';
import 'bulk_actions.dart';
import 'edit_loads_financials_sheet.dart';
import 'free_caps.dart';
import 'load_filters.dart';
import 'load_form_sheet.dart';
// import '../alerts/saved_search_service.dart';

/// Carrier-facing loads list with filters and actions.
class LoadsListScreen extends ConsumerStatefulWidget {
  const LoadsListScreen({super.key});

  @override
  ConsumerState<LoadsListScreen> createState() => _LoadsListScreenState();
}

class _LoadsListScreenState extends ConsumerState<LoadsListScreen> {
  Future<void> _logEvent(String type, Map<String, dynamic> data) async {
    try {
      final c = supa.Supabase.instance.client;
      final logger = EventLogger(c);
      await logger.log(type, data);
    } catch (_) {/* best-effort */}
  }
  // New filters state
  LoadFilters _filters = const LoadFilters();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  Timer? _debounceOrigin;
  Timer? _debounceDest;
  // Bulk selection
  final Set<String> _selected = <String>{};
  int _minCredit = 0;
  bool _loading = false;
  List<LoadItem> _items = const [];
  String? _error;
  // Filters
  String _equip = 'any';
  double? _minRpm;
  double? _originLat;
  double? _originLon;
  double _radiusMi = 50;

  @override
  void initState() {
    super.initState();
    // Default 7-day pickup window
    final now = DateTime.now();
    _filters = LoadFilters(
      pickupFromLocal: now.subtract(const Duration(days: 7)),
      pickupToLocal: now,
      equipment: 'any',
    );
    _loadSavedFilters();
    _wireDebounce();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(loadsServiceProvider);
      _items = await svc.listLoads();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _wireDebounce() {
    _originCtrl.addListener(() {
      _debounceOrigin?.cancel();
      _debounceOrigin = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _filters = _filters.copyWith(origin: _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim());
        });
        _saveFilters();
      });
    });
    _destCtrl.addListener(() {
      _debounceDest?.cancel();
      _debounceDest = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _filters = _filters.copyWith(destination: _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim());
        });
        _saveFilters();
      });
    });
  }

  Future<void> _loadSavedFilters() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final status = sp.getString('loads_filters.status');
      final equip = sp.getString('loads_filters.equipment');
      final ori = sp.getString('loads_filters.origin');
      final dst = sp.getString('loads_filters.destination');
      final fromIso = sp.getString('loads_filters.from');
      final toIso = sp.getString('loads_filters.to');
      setState(() {
        _filters = _filters.copyWith(
          status: parseLoadStatus(status),
          equipment: equip ?? _filters.equipment,
          origin: ori,
          destination: dst,
          pickupFromLocal: fromIso != null ? DateTime.tryParse(fromIso) : _filters.pickupFromLocal,
          pickupToLocal: toIso != null ? DateTime.tryParse(toIso) : _filters.pickupToLocal,
        );
        _originCtrl.text = _filters.origin ?? '';
        _destCtrl.text = _filters.destination ?? '';
      });
    } catch (_) {}
  }

  Future<void> _saveFilters() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('loads_filters.status', _filters.status != null ? LoadFilters.statusToString(_filters.status!) : '');
      await sp.setString('loads_filters.equipment', _filters.equipment ?? 'any');
      await sp.setString('loads_filters.origin', _filters.origin ?? '');
      await sp.setString('loads_filters.destination', _filters.destination ?? '');
      await sp.setString('loads_filters.from', _filters.pickupFromLocal?.toIso8601String() ?? '');
      await sp.setString('loads_filters.to', _filters.pickupToLocal?.toIso8601String() ?? '');
      // Observability: record filter usage
      await _logEvent('loads_list_filtered', {
        'status': _filters.status != null ? LoadFilters.statusToString(_filters.status!) : null,
        'origin': _filters.origin,
        'destination': _filters.destination,
        'equipment': _filters.equipment,
        'has_window': _filters.pickupFromLocal != null && _filters.pickupToLocal != null,
      });
    } catch (_) {}
  }

  void _clearAllFilters() {
    setState(() {
      final now = DateTime.now();
      _filters = LoadFilters(
        pickupFromLocal: now.subtract(const Duration(days: 7)),
        pickupToLocal: now,
        equipment: 'any',
      );
      _originCtrl.clear();
      _destCtrl.clear();
      _selected.clear();
    });
    _saveFilters();
  }

  @override
  void dispose() {
    _debounceOrigin?.cancel();
    _debounceDest?.cancel();
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _bulkPublish() async {
    // Capture context-dependent objects before awaits
    final messenger = ScaffoldMessenger.of(context);
    // Observability: attempted bulk publish
    try {
      await _logEvent('bulk_publish_attempted', {
        'selected_count': _selected.length,
      });
    } catch (_) {}
    final svc = ref.read(loadsServiceProvider);
    final isPremium = ref.read(sessionProvider).isPremium;
    final selectedLoads = _items.where((x) => _selected.contains(x.id)).toList();
    final active = await computeActiveCount(ref);
    final plan = planBulkPublish(activeCount: active, isPremium: isPremium, selected: selectedLoads);
    int ok = 0; int fail = 0;
    // Optimistic update
    final before = Map<String, String>.fromEntries(_items.map((e) => MapEntry(e.id, e.status)));
    setState(() {
      _items = _items.map((e) => plan.toPublishIds.contains(e.id) ? LoadItem(
        id: e.id,
        origin: e.origin,
        destination: e.destination,
        pickupAt: e.pickupAt,
        dropoffAt: e.dropoffAt,
        status: 'published',
        assignedDriverId: e.assignedDriverId,
        revenueCents: e.revenueCents,
        fuelCents: e.fuelCents,
        tollsCents: e.tollsCents,
        maintenanceCents: e.maintenanceCents,
        wageCents: e.wageCents,
        vehicleType: e.vehicleType,
        originLat: e.originLat,
        originLon: e.originLon,
        postedRateUsdPerMi: e.postedRateUsdPerMi,
        estimatedMiles: e.estimatedMiles,
      ) : e).toList();
    });
    for (final id in plan.toPublishIds) {
      try {
        await svc.updateStatus(loadId: id, status: 'published');
        ok += 1;
      } catch (_) {
        fail += 1;
        // rollback this id
        setState(() {
          _items = _items.map((e) => e.id == id ? LoadItem(
            id: e.id,
            origin: e.origin,
            destination: e.destination,
            pickupAt: e.pickupAt,
            dropoffAt: e.dropoffAt,
            status: before[id] ?? e.status,
            assignedDriverId: e.assignedDriverId,
            revenueCents: e.revenueCents,
            fuelCents: e.fuelCents,
            tollsCents: e.tollsCents,
            maintenanceCents: e.maintenanceCents,
            wageCents: e.wageCents,
            vehicleType: e.vehicleType,
            originLat: e.originLat,
            originLon: e.originLon,
            postedRateUsdPerMi: e.postedRateUsdPerMi,
            estimatedMiles: e.estimatedMiles,
          ) : e).toList();
        });
      }
    }
    if (!mounted) return;
    final skipped = plan.skippedDueToCapIds.length;
    // Observability: cap reached
    if (skipped > 0) {
      await _logEvent('cap_reached', {
        'feature': 'loads_active_cap',
        'skipped_due_to_cap': skipped,
      });
    }
    await _logEvent('bulk_publish_result', {
      'selected': selectedLoads.length,
      'succeeded': ok,
      'skipped': skipped,
      'failed': fail,
    });
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Bulk publish — ok: $ok, skipped: $skipped${plan.alreadyPublishedIds.isNotEmpty ? ", already published: ${plan.alreadyPublishedIds.length}" : ""}${fail>0?", failed: $fail":""}')),
    );
    _selected.clear();
    await _refresh();
  }

  Future<void> _bulkUnpublish() async {
    final svc = ref.read(loadsServiceProvider);
    final ids = _items.where((x) => _selected.contains(x.id)).map((e) => e.id).toList();
    int ok = 0; int fail = 0;
    final before = Map<String, String>.fromEntries(_items.map((e) => MapEntry(e.id, e.status)));
    setState(() {
      _items = _items.map((e) => ids.contains(e.id) ? LoadItem(
        id: e.id,
        origin: e.origin,
        destination: e.destination,
        pickupAt: e.pickupAt,
        dropoffAt: e.dropoffAt,
        status: 'draft',
        assignedDriverId: e.assignedDriverId,
        revenueCents: e.revenueCents,
        fuelCents: e.fuelCents,
        tollsCents: e.tollsCents,
        maintenanceCents: e.maintenanceCents,
        wageCents: e.wageCents,
        vehicleType: e.vehicleType,
        originLat: e.originLat,
        originLon: e.originLon,
        postedRateUsdPerMi: e.postedRateUsdPerMi,
        estimatedMiles: e.estimatedMiles,
      ) : e).toList();
    });
    for (final id in ids) {
      try {
        await svc.updateStatus(loadId: id, status: 'draft');
        ok += 1;
      } catch (_) {
        fail += 1;
        setState(() {
          _items = _items.map((e) => e.id == id ? LoadItem(
            id: e.id,
            origin: e.origin,
            destination: e.destination,
            pickupAt: e.pickupAt,
            dropoffAt: e.dropoffAt,
            status: before[id] ?? e.status,
            assignedDriverId: e.assignedDriverId,
            revenueCents: e.revenueCents,
            fuelCents: e.fuelCents,
            tollsCents: e.tollsCents,
            maintenanceCents: e.maintenanceCents,
            wageCents: e.wageCents,
            vehicleType: e.vehicleType,
            originLat: e.originLat,
            originLon: e.originLon,
            postedRateUsdPerMi: e.postedRateUsdPerMi,
            estimatedMiles: e.estimatedMiles,
          ) : e).toList();
        });
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bulk unpublish — ok: $ok${fail>0?", failed: $fail":""}')),
    );
    _selected.clear();
    await _refresh();
  }

  Future<void> _bulkDeleteDrafts() async {
    // Minimal MVP: only optimistically remove drafts locally if API lacks delete.
    // Optional: implement delete RPC/table delete.
    final ids = _items.where((x) => _selected.contains(x.id) && x.status == 'draft').map((e) => e.id).toList();
    if (ids.isEmpty) return;
    setState(() {
      _items = _items.where((e) => !ids.contains(e.id)).toList();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${ids.length} draft(s) locally')),
    );
    _selected.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () async {
                final created = await showModalBottomSheet<LoadItem>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const LoadFormSheet(),
                );
                if (created != null) {
                  await _refresh();
                  if (!mounted) return;
                  await _logEvent('quick_post_submitted', {
                    'id': created.id,
                    'origin': created.origin,
                    'destination': created.destination,
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Load created')),
                  );
                }
              },
        icon: const Icon(Icons.add),
        label: const Text('Quick Post'),
      ),
      appBar: AppBar(
        title: const Text('Loads'),
        actions: [
          IconButton(
            tooltip: 'Min Credit Score',
            icon: const Icon(Icons.verified_outlined),
            onPressed: () async {
              int tmp = _minCredit;
              final ok =
                  await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Minimum Broker Credit Score'),
                      content: SizedBox(
                        width: 320,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: tmp.toDouble(),
                              max: 100,
                              divisions: 20,
                              label: '$tmp',
                              onChanged: (v) {
                                tmp = v.round();
                              },
                            ),
                            Text('Selected: $tmp'),
                            const SizedBox(height: 6),
                            const Text(
                              'Note: Applies when broker credit data is available.',
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (ok) {
                setState(() => _minCredit = tmp);
              }
            },
          ),
          IconButton(
            tooltip: 'Save Search',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () async {
              final nameCtrl = TextEditingController(text: 'My search');
              final ok =
                  await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Save Search'),
                      content: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          isDense: true,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!ok) return;
              try {
                // Minimal filters snapshot stored via FiltersService
                final filters = <String, dynamic>{
                  'equipment': _equip,
                  if (_minRpm != null) 'min_rpm': _minRpm,
                  if (_originLat != null && _originLon != null)
                    'origin': {'lat': _originLat, 'lon': _originLon},
                  'radius_mi': _radiusMi,
                };
                final cfgUrl = const String.fromEnvironment('SUPABASE_URL');
                final cfgKey = const String.fromEnvironment('SUPABASE_ANON') != ''
                    ? const String.fromEnvironment('SUPABASE_ANON')
                    : const String.fromEnvironment('SUPABASE_ANON_KEY');
                final client = SupaClient(supabaseUrl: cfgUrl, anonKey: cfgKey);
                final svc = FiltersService(client);
                final uid = supa.Supabase.instance.client.auth.currentUser?.id;
                if (uid == null) throw Exception('Sign in required');
                await svc.save(
                  'carrier_browse',
                  uid,
                  nameCtrl.text.trim(),
                  filters,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Saved search')));
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Offline — cannot save now')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _items.isEmpty
          ? const Center(child: Text('No loads yet. Tap + to create.'))
          : Column(
              children: [
                // Filters UI
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Status selector
                      DropdownButton<LoadStatus?>(
                        value: _filters.status,
                        hint: const Text('Any status'),
                        items: const [
                          DropdownMenuItem(child: Text('Any status')),
                          DropdownMenuItem(value: LoadStatus.draft, child: Text('Draft')),
                          DropdownMenuItem(value: LoadStatus.published, child: Text('Published')),
                          DropdownMenuItem(value: LoadStatus.assigned, child: Text('Assigned')),
                          DropdownMenuItem(value: LoadStatus.inTransit, child: Text('In transit')),
                          DropdownMenuItem(value: LoadStatus.delivered, child: Text('Delivered')),
                          DropdownMenuItem(value: LoadStatus.canceled, child: Text('Canceled')),
                          DropdownMenuItem(value: LoadStatus.covered, child: Text('Covered')),
                        ],
                        onChanged: (v) {
                          setState(() => _filters = _filters.copyWith(status: v));
                          _saveFilters();
                        },
                      ),
                      // Pickup date range
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_filters.pickupFromLocal == null
                            ? 'Pickup start'
                            : _filters.pickupFromLocal!.toLocal().toString().split(' ').first),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: now.add(const Duration(days: 365)),
                            initialDate: _filters.pickupFromLocal ?? now,
                          );
                          if (picked != null) {
                            setState(() => _filters = _filters.copyWith(pickupFromLocal: picked));
                            _saveFilters();
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_filters.pickupToLocal == null
                            ? 'Pickup end'
                            : _filters.pickupToLocal!.toLocal().toString().split(' ').first),
                        onPressed: () async {
                          final base = _filters.pickupFromLocal ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: base.subtract(const Duration(days: 365)),
                            lastDate: base.add(const Duration(days: 365)),
                            initialDate: _filters.pickupToLocal ?? base,
                          );
                          if (picked != null) {
                            setState(() => _filters = _filters.copyWith(pickupToLocal: picked));
                            _saveFilters();
                          }
                        },
                      ),
                      // Origin/Destination text (debounced)
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _originCtrl,
                          decoration: const InputDecoration(labelText: 'Origin (city/zip)', isDense: true),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _destCtrl,
                          decoration: const InputDecoration(labelText: 'Destination (city/zip)', isDense: true),
                        ),
                      ),
                      // Equipment (existing)
                      DropdownButton<String>(
                        value: _equip,
                        items: const [
                          DropdownMenuItem(
                            value: 'any',
                            child: Text('Any equipment'),
                          ),
                          DropdownMenuItem(
                            value: 'dry_van',
                            child: Text('Dry Van'),
                          ),
                          DropdownMenuItem(
                            value: 'reefer',
                            child: Text('Reefer'),
                          ),
                          DropdownMenuItem(
                            value: 'flatbed',
                            child: Text('Flatbed'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _equip = v ?? 'any'),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Min USD/mi',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(
                            () => _minRpm = double.tryParse(v.trim()),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Origin Lat,Lng',
                            isDense: true,
                            hintText: 'e.g., 40.0,-83.0',
                          ),
                          onChanged: (v) {
                            final parts = v.split(',');
                            if (parts.length == 2) {
                              _originLat = double.tryParse(parts[0].trim());
                              _originLon = double.tryParse(parts[1].trim());
                            }
                            setState(() {});
                          },
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Radius'),
                          SizedBox(
                            width: 140,
                            child: Slider(
                              min: 10,
                              max: 300,
                              divisions: 29,
                              label: '${_radiusMi.round()} mi',
                              value: _radiusMi,
                              onChanged: (v) => setState(() => _radiusMi = v),
                            ),
                          ),
                          Text('${_radiusMi.round()} mi'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_filters.hasAny)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (_filters.status != null)
                              InputChip(
                                label: Text('Status: \\${LoadFilters.statusToString(_filters.status!)}'.replaceFirst('\\', '')),
                                onDeleted: () {
                                  setState(() => _filters = _filters.copyWith(clearStatus: true));
                                  _saveFilters();
                                },
                              ),
                            if ((_filters.origin ?? '').isNotEmpty)
                              InputChip(
                                label: Text('Origin: ${_filters.origin}'),
                                onDeleted: () {
                                  _originCtrl.clear();
                                  setState(() => _filters = _filters.copyWith(clearOrigin: true));
                                  _saveFilters();
                                },
                              ),
                            if ((_filters.destination ?? '').isNotEmpty)
                              InputChip(
                                label: Text('Destination: ${_filters.destination}'),
                                onDeleted: () {
                                  _destCtrl.clear();
                                  setState(() => _filters = _filters.copyWith(clearDestination: true));
                                  _saveFilters();
                                },
                              ),
                            if ((_filters.equipment ?? 'any') != 'any')
                              InputChip(
                                label: Text('Equip: ${_filters.equipment}'),
                                onDeleted: () {
                                  setState(() => _filters = _filters.copyWith(equipment: 'any'));
                                  _saveFilters();
                                },
                              ),
                            if (_filters.pickupFromLocal != null && _filters.pickupToLocal != null)
                              InputChip(
                                label: Text('Pickup: ${_filters.pickupFromLocal!.toLocal().toString().split(' ').first} → ${_filters.pickupToLocal!.toLocal().toString().split(' ').first}'),
                                onDeleted: () {
                                  setState(() => _filters = _filters.copyWith(clearWindow: true));
                                  _saveFilters();
                                },
                              ),
                          ],
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                // Bulk selection toolbar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selected.length == _filtered().length && _filtered().isNotEmpty,
                        onChanged: (v) {
                          setState(() {
                            _selected.clear();
                            if (v == true) {
                              for (final l in _filtered()) { _selected.add(l.id); }
                            }
                          });
                        },
                      ),
                      const Text('Select visible'),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.publish),
                        label: const Text('Publish'),
                        onPressed: _selected.isEmpty ? null : () async {
                          await _bulkPublish();
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.unpublished_outlined),
                        label: const Text('Unpublish'),
                        onPressed: _selected.isEmpty ? null : () async {
                          await _bulkUnpublish();
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete drafts'),
                        onPressed: _selected.isEmpty ? null : () async { await _bulkDeleteDrafts(); },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _filtered().length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = _filtered()[i];
                      return ListTile(
                        leading: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Semantics(
                                                      label: 'Select load',
                                                      child: Checkbox(
                                                        value: _selected.contains(l.id),
                                                        onChanged: (v) {
                                                          setState(() {
                                                            if (v == true) { _selected.add(l.id); } else { _selected.remove(l.id); }
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.assignment_outlined),
                                                  ],
                                                ),
                        title: Text('${l.origin} → ${l.destination}'),
                        subtitle: Text(
                          'Pickup: ${fmtDateTime(l.pickupAt)} • Drop: ${fmtDateTime(l.dropoffAt)} • Status: ${l.status}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            // Inline band chip (mocked; tap to open panel)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.trending_up),
                              label: const Text('Get band'),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.85,
                                    child: BidAssistPanel(
                                      props: BidAssistPanelProps(
                                        origin: l.origin,
                                        destination: l.destination,
                                        equipment: l.vehicleType ?? 'dry van',
                                        pickupAt: l.pickupAt.toUtc(),
                                        loadId: l.id,
                                        isPremium: ref.read(sessionProvider).isPremium,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            TextButton(
                              onPressed: () => context.push('/loads/${l.id}'),
                              child: const Text('Open'),
                            ),
                            IconButton(
                              tooltip: 'Copy Track Link',
                              icon: const Icon(Icons.link),
                              onPressed: () async {
                                final base = const String.fromEnvironment(
                                  'SUPABASE_URL',
                                );
                                final url =
                                    '$base/functions/v1/public_track?token=${l.id}';
                                await Clipboard.setData(
                                  ClipboardData(text: url),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Public track link copied'),
                                  ),
                                );
                              },
                            ),
                            if (true) // show to all for MVP; could gate by role
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    final uid = supa
                                        .Supabase
                                        .instance
                                        .client
                                        .auth
                                        .currentUser
                                        ?.id;
                                    if (uid == null) {
                                      throw Exception('Sign in required');
                                    }
                                    await retry(
                                      () => ref
                                          .read(loadsServiceProvider)
                                          .instantBook(
                                            loadId: l.id,
                                            driverUserId: uid,
                                            idempotencyKey: 'ib_${l.id}_$uid',
                                          )
                                          .timeout(const Duration(seconds: 10)),
                                      options: const RetryOptions(
                                        maxAttempts: 1,
                                      ),
                                    );
                                    // Best-effort event log
                                    try {
                                      await EventLogger(
                                        supa.Supabase.instance.client,
                                      ).log('instant_book', {
                                        'load_id': l.id,
                                        'driver_user_id': uid,
                                      });
                                    } catch (_) {}
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Booked instantly'),
                                      ),
                                    );
                                    await _refresh();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Instant Book timed out or failed.',
                                        ),
                                        action: SnackBarAction(
                                          label: 'Retry',
                                          onPressed: () async {
                                            try {
                                              final uid2 = supa
                                                  .Supabase
                                                  .instance
                                                  .client
                                                  .auth
                                                  .currentUser
                                                  ?.id;
                                              if (uid2 == null) {
                                                throw Exception(
                                                  'Sign in required',
                                                );
                                              }
                                              await retry(
                                                () => ref
                                                    .read(loadsServiceProvider)
                                                    .instantBook(
                                                      loadId: l.id,
                                                      driverUserId: uid2,
                                                      idempotencyKey:
                                                          'ib_${l.id}_$uid2',
                                                    )
                                                    .timeout(
                                                      const Duration(
                                                        seconds: 10,
                                                      ),
                                                    ),
                                                options: const RetryOptions(
                                                  maxAttempts: 1,
                                                ),
                                              );
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Booked instantly',
                                                  ),
                                                ),
                                              );
                                              await _refresh();
                                            } catch (_) {}
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Book'),
                              ),
                            OutlinedButton(
                              onPressed: () async {
                                // Fetch full details to get current financials
                                final full = await ref
                                    .read(loadsServiceProvider)
                                    .getLoad(l.id);
                                if (!context.mounted) return;
                                final ok = await showModalBottomSheet<bool>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => EditLoadFinancialsSheet(
                                    loadId: l.id,
                                    revenueCents: full.revenueCents,
                                    fuelCents: full.fuelCents,
                                    tollsCents: full.tollsCents,
                                    maintenanceCents: full.maintenanceCents,
                                    wageCents: full.wageCents,
                                  ),
                                );
                                if (ok == true) {
                                  // Refresh the list
                                  await _refresh();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Financials updated'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Edit \$'),
                            ),
                          ],
                        ),
                        onTap: () => context.push('/loads/${l.id}'),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  List<LoadItem> _filtered() {
    List<LoadItem> xs = _items;
    // Equipment
    if (_equip != 'any') {
      xs = xs.where((l) => (l.vehicleType ?? '').isEmpty ? true : l.vehicleType == _equip).toList();
    }
    // Min RPM
    if (_minRpm != null) {
      xs = xs.where((l) {
        double? rpm = l.postedRateUsdPerMi;
        if (rpm == null && l.estimatedMiles != null && l.estimatedMiles! > 0) {
          rpm = (l.revenueCents / 100.0) / l.estimatedMiles!;
        }
        return rpm == null ? true : rpm >= _minRpm!;
      }).toList();
    }
    // Geo radius filter (legacy)
    if (_originLat != null && _originLon != null) {
      double toMi(double lat1, double lon1, double lat2, double lon2) {
        const R = 3958.8; // miles
        final dLat = (lat2 - lat1) * 3.1415926535 / 180.0;
        final dLon = (lon2 - lon1) * 3.1415926535 / 180.0;
        final a = (sin(dLat / 2) * sin(dLat / 2)) +
            cos(lat1 * 3.1415926535 / 180.0) *
                cos(lat2 * 3.1415926535 / 180.0) *
                (sin(dLon / 2) * sin(dLon / 2));
        final c = 2 * atan2(sqrt(a), sqrt(1 - a));
        return R * c;
      }
      xs = xs.where((l) {
        final lat = l.originLat;
        final lon = l.originLon;
        if (lat == null || lon == null) {
          return true; // if no geo, don't filter out
        }
        final d = toMi(_originLat!, _originLon!, lat, lon);
        return d <= _radiusMi;
      }).toList();
    }
    // New filters: status
    if (_filters.status != null) {
      final s = LoadFilters.statusToString(_filters.status!);
      xs = xs.where((l) => (l.status.toLowerCase()) == s).toList();
    }
    // New filters: pickup window (normalize local to UTC range and apply to UTC pickupAt)
    if (_filters.pickupFromLocal != null && _filters.pickupToLocal != null) {
      final r = normalizeLocalDateRangeToUtc(_filters.pickupFromLocal!, _filters.pickupToLocal!);
      xs = xs.where((l) {
        final pu = l.pickupAt.toUtc();
        return !pu.isBefore(r.start) && !pu.isAfter(r.end);
      }).toList();
    }
    // New filters: origin/destination text contains (case-insensitive)
    if ((_filters.origin ?? '').isNotEmpty) {
      final needle = _filters.origin!.toLowerCase();
      xs = xs.where((l) => l.origin.toLowerCase().contains(needle)).toList();
    }
    if ((_filters.destination ?? '').isNotEmpty) {
      final needle = _filters.destination!.toLowerCase();
      xs = xs.where((l) => l.destination.toLowerCase().contains(needle)).toList();
    }
    // New filters: equipment override from _filters if set
    if ((_filters.equipment ?? 'any') != 'any') {
      xs = xs.where((l) => (l.vehicleType ?? '') == _filters.equipment).toList();
    }
    return xs;
  }
}
