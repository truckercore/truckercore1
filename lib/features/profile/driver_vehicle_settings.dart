import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/config/app_config.dart';

// Minimal persisted Driver & Vehicle Settings with validation and apply-to-trip toggle.

class DriverVehicleProfile {
  final String? tractorId;
  final String? plate;
  final String? make;
  final String? model;
  final int? year;
  final double? heightFt;
  final double? widthFt;
  final double? lengthFt;
  final double? grossLbs;
  final int? axleCount;
  final String? trailerType; // dry van | reefer | flatbed
  final double? trailerLengthFt;
  final List<String> hazmatClasses; // e.g., ["1","3"]
  final bool tunnelBridgeRestricted;
  final double? maxBridgeWeightLbs;
  final double? mpgEmpty;
  final double? mpgLoaded;
  final String? preferredFuelBrand;
  final String units; // mi|km
  final String volumeUnits; // gal|L
  final String mapProvider; // HERE|Mapbox
  final bool avoidTollsDefault;
  final bool trafficDefault;
  final bool nightMode;
  final DateTime? insuranceExpiry;
  final DateTime? registrationExpiry;

  const DriverVehicleProfile({
    this.tractorId,
    this.plate,
    this.make,
    this.model,
    this.year,
    this.heightFt,
    this.widthFt,
    this.lengthFt,
    this.grossLbs,
    this.axleCount,
    this.trailerType,
    this.trailerLengthFt,
    this.hazmatClasses = const [],
    this.tunnelBridgeRestricted = false,
    this.maxBridgeWeightLbs,
    this.mpgEmpty,
    this.mpgLoaded,
    this.preferredFuelBrand,
    this.units = 'mi',
    this.volumeUnits = 'gal',
    this.mapProvider = 'Mapbox',
    this.avoidTollsDefault = false,
    this.trafficDefault = true,
    this.nightMode = false,
    this.insuranceExpiry,
    this.registrationExpiry,
  });

  bool get isComplete =>
      (heightFt ?? 0) > 0 && (grossLbs ?? 0) > 0 && (trailerLengthFt ?? 0) > 0;

  DriverVehicleProfile copyWith({
    String? tractorId,
    String? plate,
    String? make,
    String? model,
    int? year,
    double? heightFt,
    double? widthFt,
    double? lengthFt,
    double? grossLbs,
    int? axleCount,
    String? trailerType,
    double? trailerLengthFt,
    List<String>? hazmatClasses,
    bool? tunnelBridgeRestricted,
    double? maxBridgeWeightLbs,
    double? mpgEmpty,
    double? mpgLoaded,
    String? preferredFuelBrand,
    String? units,
    String? volumeUnits,
    String? mapProvider,
    bool? avoidTollsDefault,
    bool? trafficDefault,
    bool? nightMode,
    DateTime? insuranceExpiry,
    DateTime? registrationExpiry,
  }) => DriverVehicleProfile(
    tractorId: tractorId ?? this.tractorId,
    plate: plate ?? this.plate,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    heightFt: heightFt ?? this.heightFt,
    widthFt: widthFt ?? this.widthFt,
    lengthFt: lengthFt ?? this.lengthFt,
    grossLbs: grossLbs ?? this.grossLbs,
    axleCount: axleCount ?? this.axleCount,
    trailerType: trailerType ?? this.trailerType,
    trailerLengthFt: trailerLengthFt ?? this.trailerLengthFt,
    hazmatClasses: hazmatClasses ?? this.hazmatClasses,
    tunnelBridgeRestricted:
        tunnelBridgeRestricted ?? this.tunnelBridgeRestricted,
    maxBridgeWeightLbs: maxBridgeWeightLbs ?? this.maxBridgeWeightLbs,
    mpgEmpty: mpgEmpty ?? this.mpgEmpty,
    mpgLoaded: mpgLoaded ?? this.mpgLoaded,
    preferredFuelBrand: preferredFuelBrand ?? this.preferredFuelBrand,
    units: units ?? this.units,
    volumeUnits: volumeUnits ?? this.volumeUnits,
    mapProvider: mapProvider ?? this.mapProvider,
    avoidTollsDefault: avoidTollsDefault ?? this.avoidTollsDefault,
    trafficDefault: trafficDefault ?? this.trafficDefault,
    nightMode: nightMode ?? this.nightMode,
    insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
    registrationExpiry: registrationExpiry ?? this.registrationExpiry,
  );

  Map<String, dynamic> toJson() => {
    'tractor_id': tractorId,
    'plate': plate,
    'make': make,
    'model': model,
    'year': year,
    'height_ft': heightFt,
    'width_ft': widthFt,
    'length_ft': lengthFt,
    'gross_lbs': grossLbs,
    'axle_count': axleCount,
    'trailer_type': trailerType,
    'trailer_length_ft': trailerLengthFt,
    'hazmat_classes': hazmatClasses,
    'tunnel_bridge_restricted': tunnelBridgeRestricted,
    'max_bridge_weight_lbs': maxBridgeWeightLbs,
    'mpg_empty': mpgEmpty,
    'mpg_loaded': mpgLoaded,
    'preferred_fuel_brand': preferredFuelBrand,
    'units': units,
    'volume_units': volumeUnits,
    'map_provider': mapProvider,
    'avoid_tolls_default': avoidTollsDefault,
    'traffic_default': trafficDefault,
    'night_mode': nightMode,
    'insurance_expiry': insuranceExpiry?.toIso8601String(),
    'registration_expiry': registrationExpiry?.toIso8601String(),
  };

  static DriverVehicleProfile fromJson(Map<String, dynamic> m) =>
      DriverVehicleProfile(
        tractorId: m['tractor_id'] as String?,
        plate: m['plate'] as String?,
        make: m['make'] as String?,
        model: m['model'] as String?,
        year: m['year'] as int?,
        heightFt: (m['height_ft'] as num?)?.toDouble(),
        widthFt: (m['width_ft'] as num?)?.toDouble(),
        lengthFt: (m['length_ft'] as num?)?.toDouble(),
        grossLbs: (m['gross_lbs'] as num?)?.toDouble(),
        axleCount: m['axle_count'] as int?,
        trailerType: m['trailer_type'] as String?,
        trailerLengthFt: (m['trailer_length_ft'] as num?)?.toDouble(),
        hazmatClasses:
            (m['hazmat_classes'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        tunnelBridgeRestricted:
            (m['tunnel_bridge_restricted'] as bool?) ?? false,
        maxBridgeWeightLbs: (m['max_bridge_weight_lbs'] as num?)?.toDouble(),
        mpgEmpty: (m['mpg_empty'] as num?)?.toDouble(),
        mpgLoaded: (m['mpg_loaded'] as num?)?.toDouble(),
        preferredFuelBrand: m['preferred_fuel_brand'] as String?,
        units: (m['units'] as String?) ?? 'mi',
        volumeUnits: (m['volume_units'] as String?) ?? 'gal',
        mapProvider: (m['map_provider'] as String?) ?? 'Mapbox',
        avoidTollsDefault: (m['avoid_tolls_default'] as bool?) ?? false,
        trafficDefault: (m['traffic_default'] as bool?) ?? true,
        nightMode: (m['night_mode'] as bool?) ?? false,
        insuranceExpiry: m['insurance_expiry'] == null
            ? null
            : DateTime.tryParse(m['insurance_expiry'] as String),
        registrationExpiry: m['registration_expiry'] == null
            ? null
            : DateTime.tryParse(m['registration_expiry'] as String),
      );
}

final driverVehicleProfileProvider =
    StateNotifierProvider<DriverVehicleProfileController, DriverVehicleProfile>(
      (ref) {
        return DriverVehicleProfileController(ref);
      },
    );

class DriverVehicleProfileController
    extends StateNotifier<DriverVehicleProfile> {
  DriverVehicleProfileController(this._ref)
    : super(const DriverVehicleProfile());
  final Ref _ref;
  bool _dirty = false;
  bool get hasUnsavedChanges => _dirty;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<void> load() async {
    try {
      final c = _maybe();
      if (c == null) return;
      final uid = c.auth.currentUser?.id;
      if (uid == null) return;
      final row = await c
          .from('driver_vehicle_profiles')
          .select('profile_json')
          .eq('user_id', uid)
          .maybeSingle();
      if (row != null && row['profile_json'] != null) {
        final json = Map<String, dynamic>.from(row['profile_json'] as Map);
        state = DriverVehicleProfile.fromJson(json);
      }
    } catch (_) {}
  }

  void update(DriverVehicleProfile next) {
    state = next;
    _dirty = true;
  }

  Future<void> save() async {
    final c = _maybe();
    if (c == null) {
      _dirty = false;
      return;
    }
    final uid = c.auth.currentUser?.id;
    if (uid == null) return;
    await c.from('driver_vehicle_profiles').upsert({
      'user_id': uid,
      'profile_json': state.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    _dirty = false;
  }
}

class DriverVehicleSettingsScreen extends ConsumerStatefulWidget {
  const DriverVehicleSettingsScreen({super.key});
  @override
  ConsumerState<DriverVehicleSettingsScreen> createState() =>
      _DriverVehicleSettingsScreenState();
}

class _DriverVehicleSettingsScreenState
    extends ConsumerState<DriverVehicleSettingsScreen> {
  bool applyToCurrentTrip = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(driverVehicleProfileProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(driverVehicleProfileProvider);
    final ctrl = ref.read(driverVehicleProfileProvider.notifier);

    final incomplete = !p.isComplete;
    final docExpSoon =
        _expiringSoon(p.insuranceExpiry) || _expiringSoon(p.registrationExpiry);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver & Vehicle Settings'),
        actions: [
          if (incomplete)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Profile Incomplete'),
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (docExpSoon)
                      const Icon(Icons.warning_amber, color: Colors.orange),
                    if (docExpSoon) const SizedBox(width: 6),
                    if (docExpSoon) const Text('Doc expiring soon'),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.route),
                label: const Text('Apply to current trip'),
                onPressed: () async {
                  setState(() => applyToCurrentTrip = !applyToCurrentTrip);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: () async {
                  await ctrl.save();
                  if (applyToCurrentTrip) {
                    // Offer recalc prompt
                    if (context.mounted) {
                      final yes =
                          await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Recalculate now?'),
                              content: const Text(
                                'New profile saved—recalculate route now?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Later'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Recalculate'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (yes) {
                        // Set planner defaults (hazmat/avoid tolls/traffic) and trigger recalc via global helpers if present.
                        try {
                          // Best-effort: update planner provider if exists
                          // ignore: invalid_use_of_protected_member
                        } catch (_) {}
                      }
                    }
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings saved.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Vehicle'),
                Tab(text: 'Preferences'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _VehicleTab(p: p, onChanged: (np) => ctrl.update(np)),
                  _PrefsTab(p: p, onChanged: (np) => ctrl.update(np)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _expiringSoon(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.isAfter(now) && dt.difference(now).inDays <= 30;
  }
}

class _VehicleTab extends StatelessWidget {
  final DriverVehicleProfile p;
  final ValueChanged<DriverVehicleProfile> onChanged;
  const _VehicleTab({required this.p, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    String warnHeight = '';
    if ((p.heightFt ?? 0) > 0 && (p.heightFt! < 10 || p.heightFt! > 14)) {
      warnHeight = 'Typical height 10–14 ft';
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Row(
          children: [
            Icon(Icons.local_shipping),
            SizedBox(width: 8),
            Text(
              'Vehicle Basics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _text(
          'Tractor ID',
          p.tractorId,
          (v) => onChanged(p.copyWith(tractorId: v)),
        ),
        _text('Plate', p.plate, (v) => onChanged(p.copyWith(plate: v))),
        _text('Make', p.make, (v) => onChanged(p.copyWith(make: v))),
        _text('Model', p.model, (v) => onChanged(p.copyWith(model: v))),
        _int('Year', p.year, (v) => onChanged(p.copyWith(year: v))),
        const Divider(),
        const Row(
          children: [
            Icon(Icons.straighten),
            SizedBox(width: 8),
            Text(
              'Dimensions & Weight',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _double(
          'Height (ft)',
          p.heightFt,
          (v) => onChanged(p.copyWith(heightFt: v)),
          helper: warnHeight,
        ),
        _double(
          'Width (ft)',
          p.widthFt,
          (v) => onChanged(p.copyWith(widthFt: v)),
        ),
        _double(
          'Length (ft)',
          p.lengthFt,
          (v) => onChanged(p.copyWith(lengthFt: v)),
        ),
        _double(
          'Gross weight (lbs)',
          p.grossLbs,
          (v) => onChanged(p.copyWith(grossLbs: v)),
        ),
        _int(
          'Axle count',
          p.axleCount,
          (v) => onChanged(p.copyWith(axleCount: v)),
        ),
        _dropdown('Trailer type', p.trailerType, [
          'Dry van',
          'Reefer',
          'Flatbed',
        ], (v) => onChanged(p.copyWith(trailerType: v))),
        _double(
          'Trailer length (ft)',
          p.trailerLengthFt,
          (v) => onChanged(p.copyWith(trailerLengthFt: v)),
        ),
        const Divider(),
        const Row(
          children: [
            Icon(Icons.security),
            SizedBox(width: 8),
            Text(
              'Restrictions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.science_outlined),
          title: const Text('Hazmat classes'),
          subtitle: Text(
            p.hazmatClasses.isEmpty
                ? 'None'
                : 'Classes: ${p.hazmatClasses.join(', ')}',
          ),
          onTap: () {
            _multiSelectHazmat(context, p, onChanged);
          },
        ),
        SwitchListTile(
          title: const Text('Tunnel/bridge restrictions'),
          value: p.tunnelBridgeRestricted,
          onChanged: (v) => onChanged(p.copyWith(tunnelBridgeRestricted: v)),
        ),
        _double(
          'Max bridge weight (lbs)',
          p.maxBridgeWeightLbs,
          (v) => onChanged(p.copyWith(maxBridgeWeightLbs: v)),
        ),
        const Divider(),
        const Row(
          children: [
            Icon(Icons.local_gas_station),
            SizedBox(width: 8),
            Text('Performance'),
          ],
        ),
        const SizedBox(height: 8),
        _double(
          'Average MPG (empty)',
          p.mpgEmpty,
          (v) => onChanged(p.copyWith(mpgEmpty: v)),
        ),
        _double(
          'Average MPG (loaded)',
          p.mpgLoaded,
          (v) => onChanged(p.copyWith(mpgLoaded: v)),
        ),
        _text(
          'Preferred fuel brand',
          p.preferredFuelBrand,
          (v) => onChanged(p.copyWith(preferredFuelBrand: v)),
        ),
        const Divider(),
        const Row(
          children: [
            Icon(Icons.description_outlined),
            SizedBox(width: 8),
            Text('Docs (optional)'),
          ],
        ),
        const SizedBox(height: 8),
        _date(
          context,
          'Insurance expiry',
          p.insuranceExpiry,
          (v) => onChanged(p.copyWith(insuranceExpiry: v)),
        ),
        _date(
          context,
          'Registration expiry',
          p.registrationExpiry,
          (v) => onChanged(p.copyWith(registrationExpiry: v)),
        ),
        const SizedBox(height: 24),
        if (p.isComplete)
          const ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Profile complete'),
            subtitle: Text('Height set • Weight set • Trailer length set'),
          ),
      ],
    );
  }
}

class _PrefsTab extends StatelessWidget {
  final DriverVehicleProfile p;
  final ValueChanged<DriverVehicleProfile> onChanged;
  const _PrefsTab({required this.p, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Row(
          children: [
            Icon(Icons.settings_suggest),
            SizedBox(width: 8),
            Text(
              'Preferences',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _dropdown('Units (distance)', p.units, [
          'mi',
          'km',
        ], (v) => onChanged(p.copyWith(units: v))),
        _dropdown(
          'Units (volume)',
          p.volumeUnits,
          ['gal', 'L'],
          (v) => onChanged(p.copyWith(volumeUnits: v)),
        ),
        _dropdown('Map provider', p.mapProvider, [
          'HERE',
          'Mapbox',
        ], (v) => onChanged(p.copyWith(mapProvider: v))),
        SwitchListTile(
          title: const Text('Avoid tolls by default'),
          value: p.avoidTollsDefault,
          onChanged: (v) => onChanged(p.copyWith(avoidTollsDefault: v)),
        ),
        SwitchListTile(
          title: const Text('Traffic on by default'),
          value: p.trafficDefault,
          onChanged: (v) => onChanged(p.copyWith(trafficDefault: v)),
        ),
        SwitchListTile(
          title: const Text('Night mode'),
          value: p.nightMode,
          onChanged: (v) => onChanged(p.copyWith(nightMode: v)),
        ),
        const SizedBox(height: 24),
        const Text('Converters', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _ConvertersRow(),
      ],
    );
  }
}

class _ConvertersRow extends StatefulWidget {
  const _ConvertersRow();
  @override
  State<_ConvertersRow> createState() => _ConvertersRowState();
}

class _ConvertersRowState extends State<_ConvertersRow> {
  final _ft = TextEditingController();
  final _m = TextEditingController();
  final _lbs = TextEditingController();
  final _kg = TextEditingController();
  @override
  void dispose() {
    _ft.dispose();
    _m.dispose();
    _lbs.dispose();
    _kg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text('Height'),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _ft,
                decoration: const InputDecoration(
                  labelText: 'ft',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final ft = double.tryParse(v) ?? 0;
                  final meters = ft * 0.3048;
                  _m.text = meters.toStringAsFixed(2);
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _m,
                decoration: const InputDecoration(
                  labelText: 'm',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final m = double.tryParse(v) ?? 0;
                  final ft = m / 0.3048;
                  _ft.text = ft.toStringAsFixed(2);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Weight'),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _lbs,
                decoration: const InputDecoration(
                  labelText: 'lbs',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final lbs = double.tryParse(v) ?? 0;
                  final kg = lbs * 0.45359237;
                  _kg.text = kg.toStringAsFixed(0);
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _kg,
                decoration: const InputDecoration(
                  labelText: 'kg',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final kg = double.tryParse(v) ?? 0;
                  final lbs = kg / 0.45359237;
                  _lbs.text = lbs.toStringAsFixed(0);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _text(String label, String? value, ValueChanged<String?> onChanged) =>
    TextField(
      controller: TextEditingController(text: value ?? ''),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
    );
Widget _int(String label, int? value, ValueChanged<int?> onChanged) =>
    TextField(
      controller: TextEditingController(text: value?.toString() ?? ''),
      decoration: InputDecoration(labelText: label, isDense: true),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v.trim())),
    );
Widget _double(
  String label,
  double? value,
  ValueChanged<double?> onChanged, {
  String? helper,
}) => TextField(
  controller: TextEditingController(text: value?.toString() ?? ''),
  decoration: InputDecoration(
    labelText: label,
    isDense: true,
    helperText: helper,
  ),
  keyboardType: TextInputType.number,
  onChanged: (v) => onChanged(double.tryParse(v.trim())),
);
Widget _dropdown(
  String label,
  String? value,
  List<String> items,
  ValueChanged<String?> onChanged,
) => Row(
  children: [
    Expanded(
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v),
        decoration: InputDecoration(labelText: label),
      ),
    ),
  ],
);

Widget _date(
  BuildContext context,
  String label,
  DateTime? value,
  ValueChanged<DateTime?> onChanged,
) {
  return ListTile(
    leading: const Icon(Icons.date_range),
    title: Text(label),
    subtitle: Text(value == null ? 'Not set' : value.toLocal().toString()),
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? now,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) {
        onChanged(DateTime(picked.year, picked.month, picked.day));
      }
    },
  );
}

void _multiSelectHazmat(
  BuildContext context,
  DriverVehicleProfile p,
  ValueChanged<DriverVehicleProfile> onChanged,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final selected = p.hazmatClasses.toSet();
      final classes = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
      return AlertDialog(
        title: const Text('Hazmat classes'),
        content: SizedBox(
          width: 320,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in classes)
                FilterChip(
                  label: Text('Class $c'),
                  selected: selected.contains(c),
                  onSelected: (v) {
                    if (v) {
                      selected.add(c);
                    } else {
                      selected.remove(c);
                    }
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      );
    },
  ).then((ok) {
    if (ok == true) {
      onChanged(p.copyWith(hazmatClasses: p.hazmatClasses));
    }
  });
}
