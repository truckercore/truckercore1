import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' as f;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../common/telemetry/perf_tracing.dart';
import '../../core/ab/experiment_service.dart';
import '../../core/analytics/kpi_analytics.dart';
import '../../core/flags/rollout_flags.dart';
import '../../core/formatters/time_format.dart';
import '../../core/net/error_taxonomy.dart';
import '../../core/net/retry_backoff.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/refresh/refresh_orchestrator.dart';
import '../../services/marketplace_service.dart';
import '../../shared/widgets/last_updated_badge.dart';
import '../activity/activity_service.dart';
import '../broker/ranker/ranker_service.dart' show rankerBindRef;
import '../preferences/prefs_editor_screen.dart';
import '../preferences/state/prefs_providers.dart';
import '../ranker/state/ranker_api.dart';
import '../ranker/widgets/explain_chips.dart';
import '../ranker/widgets/feedback_row.dart';

class MarketplaceBoardScreen extends ConsumerStatefulWidget {
  const MarketplaceBoardScreen({super.key});
  @override
  ConsumerState<MarketplaceBoardScreen> createState() =>
      _MarketplaceBoardScreenState();
}

class _MarketplaceBoardScreenState
    extends ConsumerState<MarketplaceBoardScreen> {
  // Track per-load outbox progress: pending/processing/done/failed + last error
  final Map<String, String> _offerUiStatus = <String, String>{}; // loadId -> label
  final Map<String, StreamSubscription> _offerWatchSubs = <String, StreamSubscription>{};
  bool _loading = false;
  String? _error;
  String _originQ = '';
  String _destQ = '';
  String _equip = 'any';
  DateTime? _date;
  double? _minPpm;
  List<MarketplaceLoad> _rows = const [];
  final _bidCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _minPpmCtrl = TextEditingController();
  bool _canSearch = false;
  final Map<String, DateTime> _lastOfferTapAt = {};
  // Ranker enrichment for UI (chips, trust, SLA)
  Map<String, RankerSuggestion> _rankerById = <String, RankerSuggestion>{};
  bool _sortByTrust = false;
  final Set<String> _busyOfferIds = <String>{};

  bool _isDebounced(String loadId) {
    final now = DateTime.now();
    final last = _lastOfferTapAt[loadId];
    if (last != null && now.difference(last).inMilliseconds < 700) {
      return true;
    }
    _lastOfferTapAt[loadId] = now;
    return false;
  }

  void _updateCanSearch(){
    final anyText = _originCtrl.text.trim().isNotEmpty || _destCtrl.text.trim().isNotEmpty;
    setState(()=> _canSearch = anyText);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final span = PerfTracer.instance.startSpan('loads.search');
    try {
      // Branch by experiment variant: treatment -> ranker_v1; control -> baseline fetch
      final isTreatment = ref.read(rankerVariantIsTreatmentProvider);
      List<MarketplaceLoad> fresh;
      if (isTreatment && ref.read(rolloutFlagsProvider).rankerV1Enabled) {
        // Call ranker_v1 edge function to get ranked items; then look up minimal load fields for display
        try {
          final filters = {
            if (_equip.isNotEmpty && _equip != 'any') 'equipment': _equip,
            if (_date != null) 'pickup_start': DateTime.utc(_date!.year, _date!.month, _date!.day).toIso8601String(),
            if (_date != null) 'pickup_end': DateTime.utc(_date!.year, _date!.month, _date!.day, 23, 59, 59).toIso8601String(),
            if (_originQ.isNotEmpty) 'origin': _originQ,
            if (_destQ.isNotEmpty) 'destination': _destQ,
            if (_minPpm != null) 'min_cpm': _minPpm,
          };
          final rr = await ref.read(rankerApiProvider).fetchRankings(
            query: '$_originQ $_destQ'.trim(),
            filters: filters,
          );
          _rankerById = {for (final s in rr.suggestions) s.id: s};
          final ids = rr.suggestions.map((e) => e.id).toList();
          if (ids.isEmpty) {
            fresh = const [];
          } else {
            // fetch minimal fields for list rendering in the same order
            final c = supa.Supabase.instance.client;
            final rowsDyn = await c.from('marketplace_loads').select('id, origin, destination, pickup_at, dropoff_at, equipment, pay_cents').inFilter('id', ids);
            final map = <String, MarketplaceLoad>{};
            for (final m in (rowsDyn as List)) {
              final mm = Map<String, dynamic>.from(m as Map);
              final item = MarketplaceLoad.fromMap(mm);
              map[item.id] = item;
            }
            fresh = ids.map((id) => map[id]).whereType<MarketplaceLoad>().toList();
          }
        } catch (_) {
          // Fallback to baseline on any failure
          final svc = ref.read(marketplaceServiceProvider);
          fresh = await runWithBackoff((_) => svc.fetchOpenLoads(
            originQ: _originQ,
            destinationQ: _destQ,
            equipment: _equip,
            date: _date,
          ), options: const RetryOptions(perAttemptTimeout: Duration(seconds: 6)));
        }
      } else {
        final svc = ref.read(marketplaceServiceProvider);
        fresh = await runWithBackoff((_) => svc.fetchOpenLoads(
          originQ: _originQ,
          destinationQ: _destQ,
          equipment: _equip,
          date: _date,
        ), options: const RetryOptions(perAttemptTimeout: Duration(seconds: 6)));
      }
      var rows = fresh;
      if (_sortByTrust && _rankerById.isNotEmpty) {
        rows = rows.toList()
          ..sort((a, b) => (_rankerById[b.id]?.trust ?? -1).compareTo(_rankerById[a.id]?.trust ?? -1));
      }
      if (_minPpm != null){
        rows = rows.where((r){
          final hours = r.dropoffAt.difference(r.pickupAt).inHours.abs();
          final miles = hours.clamp(1, 9999);
          final rpm = miles == 0 ? 0 : (r.payCents/100.0)/miles;
          return rpm >= (_minPpm ?? 0);
        }).toList();
      }
      setState(() {
        _rows = rows;
        _lastUpdated = DateTime.now();
      });
      await _persistCache();
      // Observability: log search activity
      try { await ref.read(activityServiceProvider).log(action: 'search', details: {
        if (_originQ.isNotEmpty) 'origin': _originQ,
        if (_destQ.isNotEmpty) 'dest': _destQ,
        if (_equip.isNotEmpty) 'equipment': _equip,
        if (_date != null) 'date': _date!.toIso8601String(),
        if (_minPpm != null) 'min_ppm': _minPpm,
        'result_count': rows.length,
      }); } catch (_) {}
      if (_lastRefreshWasAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated just now.')),
        );
      }
      await PerfTracer.instance.endSpan(span, ok: true);
    } catch (e) {
      final useFriendly = ref.read(rolloutFlagsProvider).friendlyErrorsEnabled;
      final traceId = DateTime.now().microsecondsSinceEpoch.toString();
      if (useFriendly) {
        final fe = ErrorTaxonomy.map(e);
        _error = fe.message;
      } else {
        _error = e.toString();
      }
      // include trace id in a debug hint and emit KPI error if available
      try { await ref.read(kpiAnalyticsProvider).emit('error_classified', {
        'trace_id': traceId,
        'kind': (_error?.contains('auth') ?? false) ? 'auth' : 'network',
      }); } catch (_) {}
      await PerfTracer.instance.endSpan(span, ok: false);
    } finally {
      if (mounted) setState(() => _loading = false);
      _lastRefreshWasAuto = false;
    }
  }

  Future<void> _hydratePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _equip = prefs.getString('mp_equipment') ?? _equip;
      _minPpm = prefs.getDouble('mp_min_ppm');
      final ts = prefs.getInt('mp_pickup_date');
      if (ts != null) _date = DateTime.fromMillisecondsSinceEpoch(ts);
      final od = prefs.getString('mp_originQ');
      final dd = prefs.getString('mp_destQ');
      if (od != null) { _originQ = od; _originCtrl.text = od; }
      if (dd != null) { _destQ = dd; _destCtrl.text = dd; }
    });
  }

  Future<void> _persistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mp_equipment', _equip);
    await prefs.setString('mp_originQ', _originQ);
    await prefs.setString('mp_destQ', _destQ);
    if (_minPpm != null) {
      await prefs.setDouble('mp_min_ppm', _minPpm!);
    } else {
      await prefs.remove('mp_min_ppm');
    }
    if (_date != null) {
      await prefs.setInt('mp_pickup_date', _date!.millisecondsSinceEpoch);
    } else {
      await prefs.remove('mp_pickup_date');
    }
  }

  DateTime? _lastUpdated;
  bool _lastRefreshWasAuto = false;

  @override
  void initState() {
    super.initState();
        // Bind ref for KPI latency emissions (ranker)
        try { rankerBindRef(ref); } catch (_) {}
    _originCtrl.addListener(_updateCanSearch);
    _destCtrl.addListener(_updateCanSearch);
    _hydratePrefs().then((_) async {
      await _hydrateCache(); // cache-first render
      // Start auto-refresh with jitter (pause on background handled by orchestrator)
      final orch = ref.read(refreshOrchestratorProvider);
      _tickSub = orch.marketplaceTicks().listen((_) async {
        _lastRefreshWasAuto = true;
        await _refresh();
      });
      if (mounted) await _refresh(); // then revalidate
    });
  }

  StreamSubscription<DateTime>? _tickSub;

  void _watchOutboxStatus(String outboxId, String loadId) {
    // Cancel prior watcher if any
    _offerWatchSubs[loadId]?.cancel();
    // Start polling action_outbox row by id every second to reflect status
    final client = supa.Supabase.instance.client;
    final sub = Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
      final row = await client
          .from('action_outbox')
          .select('status,error')
          .eq('id', outboxId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row as Map);
    }).listen((row) {
      if (!mounted) return;
      if (row == null) return;
      final status = row['status']?.toString() ?? 'pending';
      switch (status) {
        case 'pending':
          setState(() => _offerUiStatus[loadId] = 'Request sent');
          break;
        case 'processing':
          setState(() => _offerUiStatus[loadId] = 'Delivering…');
          break;
        case 'done':
          setState(() => _offerUiStatus[loadId] = 'Delivered');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivered')));
          // stop watching shortly after delivered
          Future.delayed(const Duration(milliseconds: 500), (){ _offerWatchSubs.remove(loadId)?.cancel(); });
          break;
        case 'failed':
          setState(() => _offerUiStatus[loadId] = 'Failed');
          _offerWatchSubs.remove(loadId)?.cancel();
          break;
        default:
          break;
      }
    });
    _offerWatchSubs[loadId] = sub;
  }

  @override
  void dispose(){
    _tickSub?.cancel();
    for (final s in _offerWatchSubs.values) { s.cancel(); }
    _offerWatchSubs.clear();
    _bidCtrl.dispose();
    _msgCtrl.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _minPpmCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAdvancedFilters() async {
    final dhCtrl = TextEditingController();
    DateTime? pickedDate = _date;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Advanced filters', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                DropdownButton<String>(
                  value: _equip,
                  items: const [
                    DropdownMenuItem(value: 'any', child: Text('Any equip')),
                    DropdownMenuItem(value: 'dry_van', child: Text('Dry Van')),
                    DropdownMenuItem(value: 'reefer', child: Text('Reefer')),
                    DropdownMenuItem(value: 'flatbed', child: Text('Flatbed')),
                  ],
                  onChanged: (v) { setState(() => _equip = v ?? 'any'); },
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _minPpmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Min \$/mi', isDense: true),
                    onChanged: (v){ setState(()=> _minPpm = double.tryParse(v)); },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: dhCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Max deadhead (mi)', isDense: true),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(pickedDate == null ? 'Pickup window' : pickedDate!.toLocal().toString().split(' ').first),
                  onPressed: () async {
                    final now = DateTime.now();
                    final p = await showDatePicker(
                      context: ctx,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 90)),
                      initialDate: pickedDate ?? now,
                    );
                    if (p != null) {
                      setState(()=> pickedDate = p);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              Row(children:[
                TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
                const Spacer(),
                ElevatedButton.icon(onPressed: ()=> Navigator.pop(ctx, true), icon: const Icon(Icons.check), label: const Text('Apply')),
              ])
            ],
          ),
        );
      },
    );
    if (ok == true) {
      await _persistPrefs();
      await _refresh();
    }
  }

  Future<void> _hydrateCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('mp_cached_results');
    final ts = prefs.getInt('mp_last_updated');
    if (cachedJson != null) {
      try {
        final raw = _decodeJson(cachedJson);
        final list = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map(MarketplaceLoad.fromMap)
            .toList();
        if (mounted) {
          setState(() => _rows = list);
        }
      } catch (_) {}
    }
    if (ts != null) {
      setState(() => _lastUpdated = DateTime.fromMillisecondsSinceEpoch(ts));
    }
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Store minimal payload for quick paint
    final data = _rows
        .map((e) => {
              'id': e.id,
              'origin': e.origin,
              'destination': e.destination,
              'pickup_at': e.pickupAt.toUtc().toIso8601String(),
              'dropoff_at': e.dropoffAt.toUtc().toIso8601String(),
              'equipment': e.equipment,
              'pay_cents': e.payCents,
            })
        .toList();
    final jsonStr = _encodeJson(data);
    await prefs.setString('mp_cached_results', jsonStr);
    await prefs.setInt('mp_last_updated', DateTime.now().millisecondsSinceEpoch);
  }

  String _encodeJson(Object o) => const JsonEncoder().convert(o);
  List<dynamic> _decodeJson(String s) => const JsonDecoder().convert(s) as List<dynamic>;

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(rolloutFlagsProvider);
    final prefsAsync = ref.watch(userPrefsProvider);
    final hasPersonalization = prefsAsync.maybeWhen(
      data: (p) => p.defaultEquipment != null || p.minCpm != null || p.homeBaseLat != null || p.homeBaseLng != null || p.preferredLanes.isNotEmpty || p.dislikedBrokers.isNotEmpty || p.pickupWindowStartIso != null || p.pickupWindowEndIso != null,
      orElse: () => false,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace Load Board'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: LastUpdatedBadge(
              lastUpdated: _lastUpdated,
              isRefreshing: _loading,
              onRefresh: _loading ? (){} : _refresh,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _originCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Origin',
                      isDense: true,
                      suffixIcon: _originCtrl.text.isEmpty ? null : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: (){ _originCtrl.clear(); _originQ=''; _updateCanSearch(); },
                      ),
                    ),
                    onChanged: (v) { _originQ = v; _persistPrefs(); },
                    onSubmitted: (_)=> _refresh(),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _destCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Destination',
                      isDense: true,
                      suffixIcon: _destCtrl.text.isEmpty ? null : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: (){ _destCtrl.clear(); _destQ=''; _updateCanSearch(); },
                      ),
                    ),
                    onChanged: (v) { _destQ = v; _persistPrefs(); },
                    onSubmitted: (_)=> _refresh(),
                  ),
                ),
                DropdownButton<String>(
                  value: _equip,
                  items: const [
                    DropdownMenuItem(value: 'any', child: Text('Any equip')),
                    DropdownMenuItem(value: 'dry_van', child: Text('Dry Van')),
                    DropdownMenuItem(value: 'reefer', child: Text('Reefer')),
                    DropdownMenuItem(value: 'flatbed', child: Text('Flatbed')),
                  ],
                  onChanged: (v) { setState(() => _equip = v ?? 'any'); _persistPrefs(); },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _date == null
                        ? 'Pickup Date'
                        : _date!.toLocal().toString().split(' ').first,
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 90)),
                      initialDate: now,
                    );
                    if (picked != null) { setState(() => _date = picked); _persistPrefs(); }
                  },
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _minPpmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Min \$/mi',
                      isDense: true,
                      hintText: 'e.g., 2.00',
                    ),
                    onChanged: (v){
                      final val = double.tryParse(v);
                      setState(()=> _minPpm = val);
                      _persistPrefs();
                    },
                    onSubmitted: (_)=> _refresh(),
                  ),
                ),
                FilterChip(
                  label: const Text('Sort by Trust'),
                  selected: _sortByTrust,
                  onSelected: (v) => setState(() => _sortByTrust = v),
                ),
                ElevatedButton.icon(
                  icon: _loading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.search),
                  label: const Text('Find matching loads'),
                  onPressed: _loading || !_canSearch ? null : _refresh,
                ),
              ],
            ),
          ),
          // Active filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(spacing: 8, children: [
              if (_equip != 'any') Chip(label: Text('Equip: $_equip'), onDeleted: (){ setState(()=> _equip='any'); _refresh(); }),
              if (_minPpm != null) Chip(label: Text('Min \$/mi: ${_minPpm!.toStringAsFixed(2)}'), onDeleted: (){ setState(()=> _minPpm=null); _minPpmCtrl.clear(); _refresh(); }),
            ]),
          ),
          if (flags.personalizationV1Enabled && hasPersonalization)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Card(
                color: Colors.green.withValues(alpha: 0.08),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Personalized for you'),
                  subtitle: const Text('Based on your equipment, min \u0024/mi, and lanes'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrefsEditorScreen()));
                    },
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          if (f.kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Experiment: ${ref.watch(rankerVariantIsTreatmentProvider) ? 'treatment' : 'control'}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Unable to load results', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Check your connection and try again.'),
                      if (f.kDebugMode)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: const Text('View details (debug)', style: TextStyle(fontSize: 13)),
                          children: [
                            Text(_error ?? '', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // Refine banner (progressive disclosure)
          // Live paused banner (realtime→polling fallback)
          if (ref.watch(realtimeStatusProvider) == LiveStatus.polling)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Card(
                color: Colors.amber.shade100,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.pause_circle_filled),
                  title: Text('Live paused, polling every 30s.'),
                ),
              ),
            ),
          if ((_originQ.isNotEmpty || _destQ.isNotEmpty) && _rows.length <= 2 && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Card(
                color: Colors.blueGrey.withValues(alpha: 0.06),
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Refine results'),
                  subtitle: const Text('Try advanced filters: equipment, min \$/mi, max deadhead, pickup window'),
                  trailing: TextButton(
                    onPressed: _showAdvancedFilters,
                    child: const Text('Adjust'),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _rows.isEmpty
                ? Center(child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('No results match your filters.'),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children:[
                          OutlinedButton.icon(onPressed: (){ setState((){ _equip='any'; _minPpm=null; _minPpmCtrl.clear(); }); _refresh(); }, icon: const Icon(Icons.tune), label: const Text('Relax filters')),
                          ElevatedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Try again')),
                        ])
                      ]),
                    ),
                  ))
                : ListView.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = _rows[i];
                      return ListTile(
                        leading: const Icon(Icons.assignment_outlined),
                        title: Text('${l.origin} → ${l.destination}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pickup: ${fmtDateTime(l.pickupAt)} • Pay: \$${(l.payCents / 100).toStringAsFixed(0)} • Equip: ${l.equipment ?? 'any'}'),
                            const SizedBox(height: 4),
                            if (_rankerById[l.id] != null) ExplainChips(item: _rankerById[l.id]!),
                            if (_rankerById[l.id]?.explain?['reply_minutes'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Typically replies in ~${_rankerById[l.id]!.explain!['reply_minutes']}m',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: RankerFeedbackRow(loadId: l.id),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: _busyOfferIds.contains(l.id) ? null : () async {
                            if (_isDebounced(l.id)) return;
                            setState(() => _busyOfferIds.add(l.id));
                            _bidCtrl.text = (l.payCents / 100).toStringAsFixed(
                              0,
                            );
                            _msgCtrl.text = '';
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Place Offer'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: _bidCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Bid (USD)',
                                        isDense: true,
                                      ),
                                    ),
                                    TextField(
                                      controller: _msgCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Message',
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Submit'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) { setState(() => _busyOfferIds.remove(l.id)); return; }
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
                              final cents =
                                  ((double.tryParse(_bidCtrl.text.trim()) ??
                                              0) *
                                          100)
                                      .round();
                              final res = await ref
                                  .read(marketplaceServiceProvider)
                                  .placeOffer(
                                    loadId: l.id,
                                    bidderUserId: uid,
                                    bidCents: cents,
                                    message: _msgCtrl.text.trim(),
                                  );
                              final outboxId = res['id']?.toString() ?? '';
                              if (!context.mounted) { setState(() => _busyOfferIds.remove(l.id)); return; }
                              // Optimistic UI: show Request sent and start watching status
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Request sent')),
                              );
                              setState(() => _busyOfferIds.remove(l.id));
                              _watchOutboxStatus(outboxId, l.id);
                              // Observability: log request/offer
                              try {
                                await ref.read(activityServiceProvider).log(action: 'request', details: {
                                  'load_id': l.id,
                                  'bid_cents': cents,
                                });
                              } catch (_) {}
                              // KPI analytics: request_sent
                              try {
                                await ref.read(kpiAnalyticsProvider).emit('request_sent', {
                                  'load_id': l.id,
                                  'bid_cents': cents,
                                });
                              } catch (_) {}
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          },
                          child: _busyOfferIds.contains(l.id)
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : (_offerUiStatus[l.id] == null || _offerUiStatus[l.id] == '')
                                  ? const Text('Offer')
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_offerUiStatus[l.id] == 'Request sent' || _offerUiStatus[l.id] == 'Delivering…')
                                          const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth: 2)),
                                        if (_offerUiStatus[l.id] == 'Delivered') const Icon(Icons.check, size: 16),
                                        if (_offerUiStatus[l.id] == 'Failed')
                                          IconButton(
                                            tooltip: 'Retry',
                                            icon: const Icon(Icons.refresh, size: 16),
                                            onPressed: () async {
                                              // Re-enqueue
                                              try {
                                                final uid = supa.Supabase.instance.client.auth.currentUser?.id;
                                                if (uid == null) throw Exception('Sign in required');
                                                final cents = ((double.tryParse(_bidCtrl.text.trim()) ?? 0) * 100).round();
                                                final res = await ref.read(marketplaceServiceProvider).placeOffer(
                                                  loadId: l.id,
                                                  bidderUserId: uid,
                                                  bidCents: cents,
                                                  message: _msgCtrl.text.trim(),
                                                );
                                                final outboxId = res['id']?.toString() ?? '';
                                                _watchOutboxStatus(outboxId, l.id);
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
                                              }
                                            },
                                          ),
                                        const SizedBox(width: 6),
                                        Text(_offerUiStatus[l.id]!, style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
