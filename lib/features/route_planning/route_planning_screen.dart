import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/models/app_role.dart';
import '../../common/state/session_provider.dart';
import '../../common/widgets/upgrade_card.dart';
import '../terminals/services/terminal_service.dart';
import 'truck_restrictions.dart';
import 'truck_restrictions_providers.dart';
import 'truck_restrictions_repository.dart';

// Lightweight offline cache (MVP) for reference tables
class _ReferenceCacheState {
  final DateTime? lastSyncedAt;
  final Map<String, dynamic> data; // keyed by module/state
  const _ReferenceCacheState({this.lastSyncedAt, this.data = const {}});
  _ReferenceCacheState copyWith({
    DateTime? lastSyncedAt,
    Map<String, dynamic>? data,
  }) => _ReferenceCacheState(
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    data: data ?? this.data,
  );
}

final referenceCacheProvider = StateProvider<_ReferenceCacheState>(
  (ref) => const _ReferenceCacheState(),
);

class RoutePlanningScreen extends ConsumerWidget {
  const RoutePlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isPremium = session.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📂 Route Planning'),
        actions: [
          IconButton(
            tooltip: 'RoadDogg',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.push('/roaddogg'),
          ),
          IconButton(
            tooltip: 'Confirm route',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _confirmRouteOfflineCheck(context, ref),
          ),
        ],
      ),
      body: isPremium
          ? const Column(
              children: [
                _MasterTocHeader(),
                _HazmatCompliancePanel(),
                Expanded(child: _RoleAwareContentWrapper()),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: UpgradeCard(
                title: 'Route Planning (Premium)',
                onUpgrade: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Go to subscriptions page.')),
                  );
                },
              ),
            ),
    );
  }
}

class _RoleAwareContentWrapper extends ConsumerWidget {
  const _RoleAwareContentWrapper();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider).role;
    switch (role) {
      case AppRole.driver:
      case AppRole.ownerOperator:
        return const _MobileRoutePlanning();
      case AppRole.fleetManager:
      case AppRole.broker:
        return const _WebRoutePlanning();
    }
  }
}

class _MasterTocHeader extends StatefulWidget {
  const _MasterTocHeader();
  @override
  State<_MasterTocHeader> createState() => _MasterTocHeaderState();
}

class _MasterTocHeaderState extends State<_MasterTocHeader> {
  // NOTE: Master TOC only provides quick navigation and RoadDogg access.
  // Detailed modules are shown below in role-aware sections.
  String _selected = 'HazMat';
  final List<String> _items = const [
    'HazMat',
    'On-the-Road Directory',
    'Inspection Procedure',
    'Fuel Tax & IFTA',
    'Motor Carrier Programs',
    'Mexico Regulations',
    'Canada Regulations',
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.folder_open),
            const SizedBox(width: 8),
            Text(
              'Master Table of Contents',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 12),
            ..._items.map(
              (t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t),
                  selected: _selected == t,
                  onSelected: (_) => setState(() => _selected = t),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Ask RoadDogg'),
              onPressed: () => GoRouter.of(context).push('/roaddogg'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileRoutePlanning extends StatefulWidget {
  const _MobileRoutePlanning();
  @override
  State<_MobileRoutePlanning> createState() => _MobileRoutePlanningState();
}

class _MobileRoutePlanningState extends State<_MobileRoutePlanning>
    with SingleTickerProviderStateMixin {
  static const _prefsMobileStateKey = 'routePlanning.mobile.lastState';
  static const _prefsMobileTabKey = 'routePlanning.mobile.lastTab';
  // New Jersey guide data (RoadDogg)
  static const _njInterstates = [
    'I-95 (NJ Turnpike, north–south backbone)',
    'I-78 (PA border → Newark/NYC)',
    'I-80 (PA border → NYC area)',
    'I-287 (Somerset → Mahwah loop)',
    'I-195 (Trenton → Jersey Shore)',
    'I-295 (Camden → Trenton → I-95)',
    'I-280 (Parsippany → Newark)',
    'I-76 (Camden → Philadelphia)',
    'I-676 (Camden connector)',
  ];
  static const _njUsHighways = [
    'US-1',
    'US-9 (only the US-1/9 Truck Route in Newark/Jersey City)',
    'US-22',
    'US-30',
    'US-40',
    'US-46',
    'US-130',
    'US-202',
    'US-206',
    'US-322',
  ];
  static const _njStateRoutes = [
    'NJ-55 (Glassboro → Millville → Cape May area)',
    'NJ-47 (Millville → Wildwood, Cape May access)',
    'NJ-49 (Salem → Millville → Tuckahoe)',
    'NJ-70 (Cherry Hill → Lakehurst, east–west connector)',
    'NJ-72 (Route 70 → Long Beach Island access)',
  ];
  static const _njProhibited = [
    'Garden State Parkway (entire length, Cape May → Bergen)',
    'Palisades Interstate Parkway (entire length, Bergen → NY)',
    'Atlantic City Expressway (Camden → Atlantic City)',
    'Pulaski Skyway (US-1/9 mainline Newark–Jersey City) → use US-1/9 Truck Route instead',
    'Skyline Drive (CR-692, Bergen/Passaic) → trucks >10 tons prohibited',
  ];
  static const _njWeighStations = [
    'I-78 near Greenwich Township (Warren County, EB & WB)',
    'I-80 near Allamuchy (Warren County, both directions)',
    'I-95/NJ Turnpike – inspection & weigh facilities along mainline plazas',
    'I-295 near Carneys Point (Salem County, southbound)',
    'I-295 near Hamilton Township/Trenton (northbound)',
    'I-195 near Robbinsville (eastbound)',
    'US-130 corridor – spot weigh stations in Camden/Burlington Counties',
  ];
  String _state = 'NJ';
  late final TabController _tab;
  final _states = const [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _restoreMobilePrefs();
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        _persistMobileTab(_tab.index);
      }
    });
  }

  Future<void> _restoreMobilePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefsMobileStateKey);
      final t = prefs.getInt(_prefsMobileTabKey);
      if (mounted) {
        if (s != null && s.isNotEmpty) setState(() => _state = s);
        if (t != null && t >= 0 && t < 4) _tab.index = t;
      }
    } catch (_) {}
  }

  Future<void> _persistMobileState(String s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsMobileStateKey, s);
    } catch (_) {}
  }

  Future<void> _persistMobileTab(int i) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsMobileTabKey, i);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('State:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _state,
                items: _states
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  final next = v ?? _state;
                  setState(() => _state = next);
                  _persistMobileState(next);
                },
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting playbook PDF…')),
                  );
                },
              ),
            ],
          ),
        ),
        // Driver/Owner-Op quick compliance modules
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              _OfflineCacheBanner(),
              SizedBox(height: 8),
              _DriverOwnerModules(),
            ],
          ),
        ),
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Legal Routes'),
            Tab(text: 'Prohibited'),
            Tab(text: 'Weigh Stations'),
            Tab(text: 'Compliance Tips'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _state == 'NJ'
                  ? _njLegalRoutesTab()
                  : _placeholder(
                      'STAA & Access Network list, map overlay for $_state',
                    ),
              _state == 'NJ'
                  ? _njProhibitedTab()
                  : _placeholder(
                      'Prohibited roads list (e.g., Palisades, GSP) for $_state',
                    ),
              _state == 'NJ'
                  ? _njWeighStationsTab()
                  : _placeholder(
                      'Weigh stations with alert toggle for $_state',
                    ),
              _state == 'NJ'
                  ? _njComplianceTipsTab()
                  : _placeholder('Bridge heights, hazmat notes for $_state'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _LiveRestrictionsPanel(stateCode: _state),
        ),
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ask RoadDogg: “Is NJ-49 legal for my 53’ trailer?”',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                child: const Text('Open Chat'),
                onPressed: () => GoRouter.of(context).push('/roaddogg'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder(String text) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(text),
      const SizedBox(height: 12),
      const Text('Coming soon…'),
    ],
  );

  // NJ specific tabs
  Widget _njLegalRoutesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Legal Truck Routes (STAA-Designated & Access Network)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Interstates (always truck-legal):',
          style: TextStyle(decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 4),
        ..._njInterstates.map(
          (e) => ListTile(leading: const Icon(Icons.check), title: Text(e)),
        ),
        const SizedBox(height: 8),
        const Text(
          'US Highways (legal for STAA trucks):',
          style: TextStyle(decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 4),
        ..._njUsHighways.map(
          (e) => ListTile(leading: const Icon(Icons.check), title: Text(e)),
        ),
        const SizedBox(height: 8),
        const Text(
          'NJ State Routes (Access Network):',
          style: TextStyle(decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 4),
        ..._njStateRoutes.map(
          (e) => ListTile(leading: const Icon(Icons.check), title: Text(e)),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.lightBlue.shade50,
          child: const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Rule'),
            subtitle: Text(
              'If a road is shown as a blue/orange STAA truck route, treat it as safe/legal.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _njProhibitedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Prohibited Routes (No Trucks Allowed)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._njProhibited.map(
          (e) => ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text(e),
          ),
        ),
      ],
    );
  }

  Widget _njWeighStationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Weigh Station Locations (New Jersey)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._njWeighStations.map(
          (e) => ListTile(
            leading: const Icon(Icons.scale_outlined),
            title: Text(e),
            trailing: TextButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Alert me'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'RoadDogg will alert you when approaching these stations.',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '(Weigh stations are subject to closure/open status; RoadDogg will provide live updates when possible.)',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _njComplianceTipsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Compliance Tips', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.warning_amber_outlined),
          title: Text('Conditional Restrictions'),
          subtitle: Text(
            'Local roads: Many are posted “No Trucks Except Local Delivery.” Only use these for final mile deliveries.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Low bridges & weight postings'),
          subtitle: Text(
            'Even on truck routes, check clearances and posted limits.',
          ),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.rule_folder_outlined),
          title: Text('Rulebook (Summary)'),
          subtitle: Text(
            '• Always route on Interstates, US Highways, or NJ State Routes listed above.\n• Never use Garden State Pkwy, Palisades Pkwy, Atlantic City Expwy, Pulaski Skyway, or Skyline Dr.\n• Default to blue/orange STAA-designated routes when shown.\n• Warn driver when approaching weigh stations.\n• If unsure, ask RoadDogg for the compliance check.',
          ),
        ),
      ],
    );
  }
}

class _HazmatCompliancePanel extends StatefulWidget {
  const _HazmatCompliancePanel();
  @override
  State<_HazmatCompliancePanel> createState() => _HazmatCompliancePanelState();
}

class _HazmatCompliancePanelState extends State<_HazmatCompliancePanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  color: Colors.redAccent,
                ),
                SizedBox(width: 8),
                Text(
                  'HazMat Compliance (Premium)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Basics'),
                Tab(text: 'Identifiers'),
                Tab(text: 'Incidents'),
                Tab(text: 'Emergency Numbers'),
              ],
            ),
            SizedBox(
              height: 280,
              child: TabBarView(
                controller: _tab,
                children: [
                  _hazBasics(),
                  _hazIdentifiers(),
                  _hazIncidents(),
                  _hazEmergency(),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('Quick Answer via RoadDogg'),
                onPressed: () => GoRouter.of(context).push('/roaddogg'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hazBasics() {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.assignment_turned_in_outlined),
          title: Text('Registration Requirements'),
          subtitle: Text(
            'Who must register; thresholds incl. Class 7 (radioactive).',
          ),
        ),
        ListTile(
          leading: Icon(Icons.school_outlined),
          title: Text('Training'),
          subtitle: Text(
            'General awareness, function-specific, safety, security.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.category_outlined),
          title: Text('Classification of Materials'),
          subtitle: Text(
            '9 Classes: explosives, gases, flammables, corrosives, poisons, radioactive, miscellaneous.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.description_outlined),
          title: Text('Shipping Papers'),
          subtitle: Text(
            'Bill of lading requirements, UN/NA ID, emergency contact.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.gavel_outlined),
          title: Text('Penalties'),
          subtitle: Text(
            'Fines may exceed \$55,000 per violation; criminal penalties for knowing violations.',
          ),
        ),
      ],
    );
  }

  Widget _hazIdentifiers() {
    final placards = [
      {
        'name': 'Explosives 1.1',
        'desc': '49 CFR 172',
        'ex': 'Dynamite, blasting agents',
      },
      {
        'name': 'Flammable Liquid 3',
        'desc': '49 CFR 172',
        'ex': 'Gasoline, acetone',
      },
      {'name': 'Corrosive 8', 'desc': '49 CFR 172', 'ex': 'Hydrochloric acid'},
      {'name': 'Oxidizer 5.1', 'desc': '49 CFR 172', 'ex': 'Ammonium nitrate'},
      {'name': 'Poison 6', 'desc': '49 CFR 172', 'ex': 'Cyanides'},
      {
        'name': 'Radioactive 7',
        'desc': '49 CFR 172',
        'ex': 'Class 7 materials',
      },
      {'name': 'Gas 2', 'desc': '49 CFR 172', 'ex': 'Propane, oxygen'},
      {
        'name': 'Miscellaneous 9',
        'desc': '49 CFR 172',
        'ex': 'Lithium batteries',
      },
    ];
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 3.2,
      children: placards
          .map(
            (p) => Card(
              child: ListTile(
                leading: const Icon(Icons.diamond_outlined),
                title: Text(p['name']!),
                subtitle: Text('${p['desc']} • ${p['ex']}'),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _hazIncidents() {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.block),
          title: Text('Segregation'),
          subtitle: Text(
            'Do not mix oxidizers with flammables; follow compatibility charts.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.construction_outlined),
          title: Text('Loading/Unloading'),
          subtitle: Text(
            'No smoking, proper PPE, secure containers, chock wheels.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.medical_services_outlined),
          title: Text('Incident Response'),
          subtitle: Text(
            'Follow ERG guidance; secure area, notify authorities.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.report_outlined),
          title: Text('Reporting'),
          subtitle: Text(
            'Notify NRC within 12 hours when required; document details.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.security),
          title: Text('Anti-Terrorism Tips'),
          subtitle: Text(
            'Security awareness, vet unusual requests, secure cargo.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.checklist_outlined),
          title: Text('Cab Checklist'),
          subtitle: Text(
            'ERG guide, MSDS, shipping papers, emergency contacts.',
          ),
        ),
      ],
    );
  }

  Widget _hazEmergency() {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.phone_in_talk_outlined),
          title: Text('NRC (US National Response Center)'),
          subtitle: Text('1-800-424-8802'),
        ),
        ListTile(
          leading: Icon(Icons.support_agent_outlined),
          title: Text('CHEMTREC'),
          subtitle: Text('1-800-262-8200'),
        ),
        ListTile(
          leading: Icon(Icons.language),
          title: Text('International (examples)'),
          subtitle: Text(
            'Canada CANUTEC: 1-888-CAN-UTEC • Mexico Emergencias locales',
          ),
        ),
        ListTile(
          leading: Icon(Icons.offline_bolt_outlined),
          title: Text('Offline Access'),
          subtitle: Text(
            'Emergency numbers should be available offline in the driver app.',
          ),
        ),
      ],
    );
  }
}

class _DriverOwnerModules extends ConsumerWidget {
  const _DriverOwnerModules();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider).role;
    // Only Drivers and Owner-Ops see these modules on mobile
    if (role != AppRole.driver && role != AppRole.ownerOperator) {
      return const SizedBox.shrink();
    }
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _OnTheRoadDirectoryCard(),
        _InspectionProcedureCard(),
        _FuelTaxBasicsCard(),
        _StateAccessPoliciesCard(),
        _LcvRulesCard(),
        _WeightSizeLimitsCard(),
        _TrailerCombinationLimitsCard(),
        _CrossBorderQuickCheckCard(),
      ],
    );
  }
}

class _FleetModules extends StatelessWidget {
  const _FleetModules();
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _FuelTaxIfTAPlanningCard(),
        _StateAccessPoliciesPlannerCard(),
        _LcvPlannerCard(),
        _WeightSizePlannerCard(),
        _TrailerCombinationPlannerCard(),
        _MotorCarrierProgramsCard(),
        _CrossBorderComplianceCard(),
      ],
    );
  }
}

class _BrokerModules extends StatelessWidget {
  const _BrokerModules();
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _FuelTaxImpactCard(),
        _StateAccessPoliciesPlannerCard(),
        _LcvPlannerCard(),
        _WeightSizePlannerCard(),
        _TrailerCombinationPlannerCard(),
        _MotorCarrierProgramsCard(),
        _CrossBorderRegulationsCard(),
      ],
    );
  }
}

class _WebModulesBar extends ConsumerWidget {
  const _WebModulesBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider).role;
    if (role == AppRole.fleetManager) return const _FleetModules();
    if (role == AppRole.broker) return const _BrokerModules();
    return const SizedBox.shrink();
  }
}

// Analytics helper (MVP)
void _logEvent(String name, [Map<String, Object?> props = const {}]) {
  // Replace with real analytics later
  // ignore: avoid_print
  print('[analytics] $name ${props.isEmpty ? '' : props}');
}

// Search normalization and aliases (MVP)
String _normalizeRouteLabel(String s) {
  var t = s.trim();
  // common synonyms to canonical
  t = t.replaceAll(
    RegExp(r'\bGSP\b', caseSensitive: false),
    'Garden State Parkway',
  );
  t = t.replaceAll(RegExp(r'\bThruway\b', caseSensitive: false), 'I-87');
  t = t.replaceAll(RegExp(r'\bLIE\b', caseSensitive: false), 'I-495');
  t = t.replaceAll(RegExp(r'\bCross Bronx\b', caseSensitive: false), 'I-95');
  // normalize prefixes like I , I–, Interstate to I-
  t = t.replaceAll(RegExp(r'\bInterstate\s+', caseSensitive: false), 'I-');
  t = t.replaceAll(RegExp(r'\bI[\s–—]+'), 'I-');
  t = t.replaceAll(RegExp(r'\bUS[\s–—]+'), 'US ');
  t = t.replaceAll(RegExp(r'\bSR[\s–—]+'), 'SR ');
  t = t.replaceAll(RegExp(r'\bState\s+Route\s+', caseSensitive: false), 'SR ');
  return t;
}

String _normalizeHeight(String s) {
  // Normalize 13’6” / 13'6" to 13'6"
  final t = s.replaceAll('’', "'").replaceAll('“', '"').replaceAll('”', '"');
  // Ensure feet'inches"
  final m = RegExp("(\\d{1,2})\\s*'?\\s*(\\d{1,2})\\s*\"?").firstMatch(t);
  if (m != null) {
    final ft = m.group(1);
    final inch = m.group(2);
    return "$ft'$inch\"";
  }
  return t;
}

// On-the-Road Directory data models (MVP)
class _ClearanceItem {
  final String route;
  final String location;
  final String height; // e.g., 13'6"
  // ignore: unused_element_parameter
  const _ClearanceItem({
    required this.route,
    required this.location,
    required this.height,
  });
}

class _WeighStationItem {
  final String highway;
  final String location; // mile marker or description
  final String direction; // NB/SB/EB/WB or Both
  // ignore: unused_element_parameter
  const _WeighStationItem({
    required this.highway,
    required this.location,
    required this.direction,
  });
}

class _RestrictedRouteItem {
  final String designation; // e.g., I-10 Mobile Wallace Tunnel
  final String restriction; // hazmat prohibited, length, bridge, etc.
  const _RestrictedRouteItem({
    required this.designation,
    required this.restriction,
  });
}

class _StateDirectoryRecord {
  final String stateCode; // e.g., AL
  final List<_ClearanceItem> clearances;
  final List<_WeighStationItem> weighStations;
  final List<_RestrictedRouteItem> restricted;
  const _StateDirectoryRecord({
    required this.stateCode,
    required this.clearances,
    required this.weighStations,
    required this.restricted,
  });
}

// Seed data for Alabama (example)
final _onTheRoadSeed = <String, _StateDirectoryRecord>{
  /*
  'AL': _StateDirectoryRecord(
    stateCode: 'AL',
    clearances: const [
      _ClearanceItem(route: 'AL', location: 'Greenville', height: "10'0\""),
      _ClearanceItem(route: 'US 11', location: 'York', height: "13'4\""),
      _ClearanceItem(route: 'AL 53', location: 'Ardmore-West, east of jct. I-65', height: "11'6\""),
      _ClearanceItem(route: 'US 82', location: 'Gordo', height: "13'6\""),
      _ClearanceItem(route: 'US 90/98', location: 'Mobile — Bankhead Tunnel', height: "12'0\""),
      _ClearanceItem(route: 'AL 111', location: 'Wetumpka — Coosa River Bridge', height: "12'6\""),
      _ClearanceItem(route: 'Swan Bridge Rd', location: 'Cleveland — 1 mi. W at Locust Fork River Bridge', height: "13'0\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-20', location: 'New Hopewell — MP 209', direction: 'WB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'I-10 — Mobile Wallace Tunnel', restriction: 'Restricted for Hazmat'),
      _RestrictedRouteItem(designation: 'AL 22 — AL 191 to Chilton Co. Hwy. 15', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 26 — Hurtsboro to US 431', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 37 — AL 84 to Fort Rucker', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 77 — I-59 to US 411 (Rainbow City)', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 81 — I-85 exit 38 to Notasulga', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 105 — Ozark to AL 10', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 106 — US 31 to US 29', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 111 — Wetumpka over Coosa River', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 179 — US 278 to AL 168', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'US 231 — Oneonta to US 11', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'AL 235 — US 231 to Laniers', restriction: 'Restriction in effect'),
      _RestrictedRouteItem(designation: 'Natchez Trace Pkwy — MS line to TN line', restriction: 'NP for trucks (federal parkway)'),
    ],
  ),
  'AK': _StateDirectoryRecord(
    stateCode: 'AK',
    clearances: const [
      _ClearanceItem(route: 'Calhoun Ave', location: 'Juneau', height: "13'3\""),
      _ClearanceItem(route: 'Dyea Road', location: 'Skagway', height: "11'2\""),
      _ClearanceItem(route: 'Old Sterling Hwy', location: 'Anchor Point', height: "13'2\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'AK 1 (Glenn Hwy.)', location: 'Anchorage — approx. 11 mi NE — MP 10.6', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'AK 1 (Seward Hwy.)', location: 'Anchorage — approx. 10 mi S — Potters Marsh — MP 115.5', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'AK 1 (Sterling Hwy.)', location: 'Sterling — approx. 14 mi E — MP 82.5', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'AK 2 (Alaska Hwy.)', location: 'Tok — approx. 5 mi E — MP 1308.6', direction: 'NB/SB', poe: 'POE nearby/portable scales used'),
      _WeighStationItem(highway: 'AK 2 (Richardson Hwy.)', location: 'Fairbanks — MP 357.8', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'AK 2 (Elliot & Steese Hwys.)', location: 'Fairbanks — ~10 mi N — Elliot MP 0 / Steese MP 11.5', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'AK 3 (George Parks Hwy.)', location: 'Fairbanks — ~10 mi SW — MP 356', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      // None reported
    ],
  ),
  'AZ': _StateDirectoryRecord(
    stateCode: 'AZ',
    clearances: const [
      _ClearanceItem(route: 'AZ 84 EB', location: 'Casa Grande — MP 177.66', height: "13'3\""),
      _ClearanceItem(route: 'US 191', location: 'Morenci — tunnel at MP 169.90', height: "12'6\""),
      _ClearanceItem(route: 'AZ 288', location: '4 mi north of jct. AZ 188 at Salt River — MP 262.44', height: "12'3\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-8', location: 'Yuma — 3 mi east of CA state line', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-8 Bus', location: 'Yuma — 3 mi east of CA state line', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Ehrenburg — 1 mi east of CA state line', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'San Simon — 7 mi west of NM state line', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-15', location: 'Black Rock — 0.75 mi north of Exit 27', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-19', location: 'Nogales — at US–Mexico border', direction: 'NB/SB', poe: 'POE'),
      _WeighStationItem(highway: 'I-40', location: 'Sanders — 20 mi west of NM state line', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-40', location: 'Topock — 3.8 mi east of CA state line', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'US 60', location: 'Springerville — 25 mi west of NM state line', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'US 70', location: 'Duncan/Franklin — 4 mi west of NM state line', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'US 95', location: 'Parker — 1 mi east of CA state line', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 95', location: 'Lukeville — just north of Mexico border', direction: 'NB/SB', poe: 'POE'),
      _WeighStationItem(highway: 'US 89 Alt', location: 'Page — 5 mi south of UT state line', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 89 Alt', location: 'Fredonia — 5 mi south of UT state line', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 93', location: 'Kingman — 1.3 mi northwest', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 95', location: 'San Luis — just north of Mexico border', direction: 'NB/SB', poe: 'POE'),
      _WeighStationItem(highway: 'US 160', location: 'Teec Nos Pos — 6 mi west of NM state line', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 191', location: 'Douglas — at jct. US 80', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'AZ 286', location: 'Sasabe — just north of Mexico border', direction: 'NB/SB', poe: 'POE'),
      _WeighStationItem(highway: 'Towner Ave', location: 'Naco — just north of Mexico border', direction: 'NB/SB', poe: 'POE'),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'AZ 64 — Grand Canyon to jct. US 89', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 67 — Jacob Lake to North Rim', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 88 — AZ 188 to US 60', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 89A — Prescott to jct. US 93', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 89A — AZ 89 to I-17', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 89A — AZ 87 to AZ 260', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 191 — Morenci to Alpine', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 261 — AZ 260 to AZ 273', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 273 — Bonita to US 191', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 273 — AZ 260 to AZ 261', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 288 — Young to AZ 88', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 366 — I-19 to Arivaca', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 366 — Turkey Flat to US 191', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'AZ 473 — Hawley Lake to AZ 260', restriction: 'Restricted'),
    ],
  ),
  'AR': _StateDirectoryRecord(
    stateCode: 'AR',
    clearances: const [
      _ClearanceItem(route: 'AR 7', location: 'Camden, north, 0.8 mi. northwest of US 79', height: "12'8\""),
      _ClearanceItem(route: 'AR 42', location: 'Turrell, 0.01 mi. east of AR 77', height: "11'6\""),
      _ClearanceItem(route: 'AR 69', location: 'Trumann, 0.82 mi. east of AR 463', height: "9'6\""),
      _ClearanceItem(route: 'AR 69 Spur', location: 'Trumann, south of AR 69', height: "12'0\""),
      _ClearanceItem(route: 'AR 75', location: 'Parkin', height: "13'6\""),
      _ClearanceItem(route: 'AR 134', location: 'Garland City, jct. US 82', height: "13'6\""),
      _ClearanceItem(route: 'AR 282', location: 'Mountainburg, approx. 4.5 mi. southwest', height: "12'1\""),
      _ClearanceItem(route: 'AR 296', location: 'Mandeville, approx. 0.5 mi. southwest', height: "11'6\""),
      _ClearanceItem(route: 'AR 331', location: 'Pottsville, 0.11 mi. south of US 64', height: "12'0\""),
      _ClearanceItem(route: 'AR 365', location: 'North Little Rock, 0.4 mi. west of US 70', height: "12'6\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-30', location: 'Guernsey — 4 mi. southwest of Hope', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-40', location: 'Alma — 4.5 mi. west', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-40', location: 'Riverside — just west of Tennessee state line', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-40', location: 'West Memphis — 11.5 mi. west', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-49', location: 'Springdale', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Blytheville — south of Missouri state line', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Bridgeport — east of West Memphis', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Marion — south of US 64', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 71', location: 'Ashdown', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      // None provided in this issue scope
    ],
  ),
  'CA': _StateDirectoryRecord(
    stateCode: 'CA',
    clearances: const [
      _ClearanceItem(route: 'I-5 NB', location: 'San Diego, Pershing Dr. off ramp', height: "13'10\""),
      _ClearanceItem(route: 'CA 33 NB/SB', location: 'Ventura, Matilija Tunnels', height: "13'6\""),
      _ClearanceItem(route: 'CA 110 NB', location: 'Los Angeles, College St. overpass', height: "13'6\""),
      _ClearanceItem(route: 'CA 110 NB', location: 'Los Angeles, Hill St. overpass', height: "13'5\""),
      _ClearanceItem(route: 'TCA 151 EB/WB', location: 'Summit City, Coram overpass', height: "13'6\""),
      _ClearanceItem(route: 'CA 238 SB', location: 'Fremont, 2.2 mi. north of I-680', height: "14'0\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'CA 4', location: 'Murphys', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-5', location: 'Castaic', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-5', location: 'Cottonwood', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-5', location: 'Grapevine', direction: 'SB', poe: '†'),
      _WeighStationItem(highway: 'I-5', location: 'Mt. Shasta, south', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-5', location: 'San Onofre, 5.25 mi. south of San Clemente', direction: 'NB/SB', poe: '†'),
      _WeighStationItem(highway: 'I-5', location: 'Santa Nella Village, north of jct. CA 33', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'CA 7', location: 'Calexico, east of E. Carr Rd.', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-8', location: 'Winterhaven, 6 mi. west', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Banning, east of CA 243', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Blythe, west', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-15', location: 'Cajon Junction', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-15', location: 'Mountain Pass, east', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-15', location: 'Rainbow', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'CA 50', location: 'Camino', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'CA 58', location: 'Keene', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'CA 58', location: 'Mojave, 7 mi. west of CA 14', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'CA 70', location: 'Keddie, at jct. CA 89', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Antelope, 12.5 mi. NE of downtown Sacramento', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Cordelia, southwest of Fairfield', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Truckee, east of CA 89', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'CA 91', location: 'Anaheim, Peralta Hills area', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'CA 99', location: 'Chowchilla, north', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 101', location: 'Gilroy', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 101', location: 'Little River, 8.5 mi. north of Arcata', direction: 'NB', poe: '†'),
      _WeighStationItem(highway: 'I-580', location: 'San Rafael, 3.5 mi. north of jct. I-580', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-580', location: 'San Rafael, 4.5 mi. north of jct. I-580', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 101', location: 'Thousand Oaks, 6 mi. north of CA 23', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 101', location: 'Willits, 6 mi. south', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'CA 108', location: 'Lyons Dam, northeast of Long Barn', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'CA 298', location: 'Tecate', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'CA 299', location: 'Blue Lake', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'CA 299', location: 'Whiskeytown', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-580', location: 'Livermore', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-680', location: 'Fremont', direction: 'NB/WB', poe: null),
      _WeighStationItem(highway: 'CA 24', location: 'Walnut Creek', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-880', location: 'Fremont', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-805', location: 'Enrico Fermi Dr., NB, Otay Mesa, east of CA 905', direction: 'EB/WB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'CA 1 — LAX Sepulveda Tunnel', restriction: 'Combustibles or flammables only'),
      _RestrictedRouteItem(designation: 'CA 1 — Pacifica Tom Lantos Tunnels', restriction: 'Explosives, flammables, or combustibles only'),
      _RestrictedRouteItem(designation: 'CA 1 — CA 27 to CA 23', restriction: 'No through trucks with 4 or more axles'),
      _RestrictedRouteItem(designation: 'CA 1 — CA 246 to Central Ave.', restriction: 'No trucks over 3 tons (†)'),
      _RestrictedRouteItem(designation: 'CA 1 — I-210 to Big Pines Hwy.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CA 20 — CA 29 to CA 53', restriction: 'Hazmat only'),
      _RestrictedRouteItem(designation: 'CA 24 — Oakland Caldecott Tunnel', restriction: 'Explosives, flammables, or poisonous gas only'),
      _RestrictedRouteItem(designation: 'CA 25 — Coronado Bay Bridge', restriction: 'Corrosives, explosives, or flammables only'),
      _RestrictedRouteItem(designation: 'CA 61 — Oakland Bay Bridge (SF)', restriction: 'Explosives or flammables only'),
      _RestrictedRouteItem(designation: 'CA 83 — Upland Base Line Rd. to CA 30', restriction: 'No trucks over 5 tons'),
      _RestrictedRouteItem(designation: 'CA 84 — Cache Slough Ferry', restriction: 'No tractor-trailers'),
      _RestrictedRouteItem(designation: 'CA 238 to I-680', restriction: 'Hazmat only'),
      _RestrictedRouteItem(designation: 'US 101 to I-280', restriction: 'No trucks over 4.5 tons'),
      _RestrictedRouteItem(designation: 'CA 108 — Tuolumne/Mono Co. line to W of US 395', restriction: 'No trucks with KPRA over 38 feet'),
      _RestrictedRouteItem(designation: 'CA 110 — Pasadena US 101 to Glenarm St.', restriction: 'No trucks over 3 tons'),
      _RestrictedRouteItem(designation: 'CA 152 — Watsonville Carlton Rd. to Gilroy, Watsonville Rd.', restriction: 'No vehicles over 45 ft.'),
      _RestrictedRouteItem(designation: 'CA 154 — CA 246 to US 101', restriction: 'Hazmat only'),
      _RestrictedRouteItem(designation: 'CA 170 — at NB US 101 on-ramp', restriction: 'Turning movement restriction'),
      _RestrictedRouteItem(designation: 'CA 173 — CA 138 to CA 189', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CA 175 — US 101 to CA 29', restriction: 'No vehicles over 39 ft.'),
      _RestrictedRouteItem(designation: 'CA 183 SB — CA 156 to CA 1', restriction: 'No trucks over 7 tons (detour available)'),
      _RestrictedRouteItem(designation: 'CA 220 — J-Mac Ferry N of Rio Vista', restriction: 'No tractor-trailers'),
      _RestrictedRouteItem(designation: 'CA 246 — Lompoc to CA 1', restriction: 'No trucks over 3 tons'),
      _RestrictedRouteItem(designation: 'CA 260 — Alameda Central Ave. to I-880', restriction: 'Hazmat only (†)'),
      _RestrictedRouteItem(designation: 'I-580 — San Leandro Foothill Blvd. to Oakland Grand Ave.', restriction: 'No trucks over 4.5 tons (†)'),
    ],
  ),
  'CO': _StateDirectoryRecord(
    stateCode: 'CO',
    clearances: const [
      _ClearanceItem(route: 'US 6', location: 'Eagle, 0.67 mi. east at Eagle River — MP 150.24', height: "14'4\""),
      _ClearanceItem(route: 'CO 14', location: 'Poudre Park, tunnel 4.7 mi. west — MP 107.55', height: "14'5\""),
      _ClearanceItem(route: 'US 50 Bus EB (Santa Fe Ave.)', location: 'Pueblo, just south of I-25/US 85/87 at Arkansas River', height: "13'6\""),
      _ClearanceItem(route: 'I-70 EB', location: 'Idaho Springs — MP 238.689', height: "14'0\""),
      _ClearanceItem(route: 'I-70/US40/US285', location: 'Deer Trail, 4.92 mi. west — MP 238.689', height: "14'3\""),
      _ClearanceItem(route: 'US 95 NB/SB (Sheridan Blvd.)', location: 'Denver, at I-70 — MP 9.013', height: "14'1\""),
      _ClearanceItem(route: 'CO 144', location: 'Fort Morgan, at I-76 overpass — MP 0.01', height: "16'11\""),
      _ClearanceItem(route: 'CO 265', location: 'Commerce City, 0.5 mi. north of Race St.', height: "11'4\" – 11'5\""),
      _ClearanceItem(route: 'US 550/CO 789', location: 'Ouray Tunnel, 1.17 mi. south — MP 90.86', height: "13'9\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-25/US 85/87', location: 'Timnath — 1.6 mi. south of CO 14', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-25/US 85/87', location: 'Monument — 0.5 mi. north of CO 105', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-25/US 85/87', location: 'Trinidad — 2.4 mi. south (joint port with NM)', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-25/US 85/87', location: 'Lamar — 0.5 mi. west of CO 196', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-25/US 85/87', location: 'Walsenburg — 0.5 mi. south of CO 10', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Loma — 4 mi. west of Fruita (joint with UT)', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Lawson — 1.5 mi. west', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-76', location: 'Fort Morgan — 6 mi. west of jct. US 34 & US 6', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-76', location: 'Platteville — 0.5 mi. south of CO 66', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 160/491', location: 'Cortez — 2 mi. south', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'CO 10 — US 50 to CO 71', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 12 — US 160 to I-25', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 14 — CO 125 to US 287', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 17 — Capulin to US 160', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 17 — New Mexico state line to US 285', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 34 — Grand Lake to US 36', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 34 — US 34 to Estes Park', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 50 — Sargents to Maysville', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 65 — US 65 to US 138', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 65 — US 65 to I-70', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 67 — Cripple Creek to US 24', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 69 — US 350 to CO 10', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 86 — CO 115 to Pueblo County Road 212', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 82 — Aspen to Twin Lakes', restriction: 'Max truck length 35’'),
      _RestrictedRouteItem(designation: 'CO 91 — US 285 to CO 165', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 92 — Sugar City to Arlington', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 96 — CO 103 to end of road', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 109 — CO 72 to CO 7', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 119 — Oak Creek to US 40', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 133 — Bowie to CO 82', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 138 — Sterling to US 6', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 149 — Creede to CO 112', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 150 — US 285 to CO 17', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 160 — east of Las Animas County line to Pritchett', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 200 — US 50 to CO 78', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 277 — CO 119 to Central City', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 325 — CO 13 to Rifle Falls State Park', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CO 330 — CO 65 to Colibran', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 550 — Hermosa to Ouray', restriction: 'Restricted'),
    ],
  ),
  'CT': _StateDirectoryRecord(
    stateCode: 'CT',
    clearances: const [
      _ClearanceItem(route: 'US 1', location: 'Branford, northeast of CT 142', height: "13'7\""),
      _ClearanceItem(route: 'US 1', location: 'Darien, 0.1 mi. southwest of CT 124', height: "13'6\""),
      _ClearanceItem(route: 'US 1', location: 'Madison, 2.1 mi. west of CT 79', height: "13'6\""),
      _ClearanceItem(route: 'US 1', location: 'Milford, Milford Pkwy. Overpass', height: "13'3\""),
      _ClearanceItem(route: 'US 1', location: 'Stamford, 0.6 mi. west of I-95', height: "12'0\""),
      _ClearanceItem(route: 'CT 6', location: 'Bristol, 0.4 mi. west of CT 69', height: "12'7\""),
      _ClearanceItem(route: 'CT 10', location: 'Farmington, US 6 overpass', height: "13'9\""),
      _ClearanceItem(route: 'CT 10', location: 'Hamden, 0.4 mi. west of CT 15', height: "11'8\""),
      _ClearanceItem(route: 'CT 12', location: 'Lisbon, I-395 overpass', height: "12'7\""),
      _ClearanceItem(route: 'CT 53', location: 'Bethel, 1.3 mi. south of CT 302', height: "12'0\""),
      _ClearanceItem(route: 'CT 53', location: 'Norwalk, CT 15 overpass', height: "11'7\""),
      _ClearanceItem(route: 'CT 53', location: 'Westport, CT 15 overpass', height: "12'2\""),
      _ClearanceItem(route: 'CT 71', location: 'Wallingford', height: "13'0\""),
      _ClearanceItem(route: 'CT 72', location: 'Plymouth, 0.2 mi. west of Hartford County line', height: "13'3\""),
      _ClearanceItem(route: 'CT 81', location: 'Clinton, 0.1 mi. north of US 1', height: "11'10\""),
      _ClearanceItem(route: 'CT 104', location: 'Stamford, CT 15 overpass', height: "11'9\""),
      _ClearanceItem(route: 'CT 106', location: 'New Canaan, 0.4 mi. north of CT 15', height: "12'11\""),
      _ClearanceItem(route: 'CT 106', location: 'New Canaan, CT 15 overpass', height: "11'10\""),
      _ClearanceItem(route: 'CT 113', location: 'Stratford, 0.2 mi. north of I-95', height: "12'1\""),
      _ClearanceItem(route: 'CT 113', location: 'Stratford, RR north of I-95', height: "11'11\""),
      _ClearanceItem(route: 'CT 130', location: 'Seymour, 0.2 mi. east of CT 8', height: "12'3\""),
      _ClearanceItem(route: 'CT 133', location: 'Bridgeport, I-95 overpass', height: "12'0\""),
      _ClearanceItem(route: 'CT 135', location: 'Brookfield, 0.2 mi. east of US 7/202', height: "10'10\""),
      _ClearanceItem(route: 'CT 137', location: 'Fairfield, 0.1 mi. south of I-95', height: "10'7\""),
      _ClearanceItem(route: 'CT 137', location: 'Westport, 0.1 mi. south of I-95', height: "10'9\""),
      _ClearanceItem(route: 'CT 138', location: 'Stamford, CT 15 overpass', height: "11'9\""),
      _ClearanceItem(route: 'CT 145', location: 'Lisbon, southwest, 1 mi. west of CT 12', height: "12'7\""),
      _ClearanceItem(route: 'CT 146', location: 'Branford, RR north of Branford River', height: "12'6\""),
      _ClearanceItem(route: 'CT 146', location: 'Branford, south of US 1', height: "10'6\""),
      _ClearanceItem(route: 'CT 146', location: 'Guilford, 1.25 mi. southwest', height: "11'6\""),
      _ClearanceItem(route: 'CT 146', location: 'Leetes Island', height: "11'8\""),
      _ClearanceItem(route: 'CT 159', location: 'Windsor, 0.1 mi. northeast of CT 305', height: "12'9\""),
      _ClearanceItem(route: 'CT 243', location: 'New Haven, CT 15 overpass', height: "12'6\""),
      _ClearanceItem(route: 'CT 275', location: 'Eagleville, 0.2 mi. west of CT 32', height: "12'0\""),
      _ClearanceItem(route: 'CT 322 WB', location: 'Milldale, CT 10 overpass', height: "12'7\""),
      _ClearanceItem(route: 'CT 533', location: 'Vernon, 0.06 south of I-84', height: "12'0\""),
      _ClearanceItem(route: 'CT 598', location: 'Hartford, Library Building', height: "13'3\""),
      _ClearanceItem(route: 'CT 598', location: 'Hartford, Main St. overpass', height: "12'9\""),
      _ClearanceItem(route: 'CT 598', location: 'Hartford, Prospect St. overpass', height: "10'11\""),
      _ClearanceItem(route: 'CT 649', location: 'Groton, 2.25 mi. east of CT 349', height: "10'6\""),
      _ClearanceItem(route: 'CT 847', location: 'Waterbury', height: "12'10\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-84', location: 'Danbury — Exit 2', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-84', location: 'Union — 3.4 mi. south of MA state line', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-91', location: 'Middletown — 1.4 mi. north of Exit 18', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Greenwich — 0.9 mi. south of Exit 3', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Waterford — 1.1 mi. west of CT 85', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Waterford — 1.3 mi. west of CT 85', direction: 'SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'CT 15 — NY state line to I-91', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 63 — CT 63 to CT 10', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 42 — CT 67 to CT 8', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 49 — CT 216 to CT 138', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 49 — CT 49 to CT 151', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 89 — CT 195 to Mt. Hope', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 97 — CT 14 to US 6', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 109 — US 202 to CT 61', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 136 — CT 57 to CT 59', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 145 — CT 80 to CT 148', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 146 — CT 22 to I-91', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 189 — CT 539 to MA state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 198 — Chaplin to US 6', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 219 — CT 49 to Clark Falls', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'CT 796 (Milford Pkwy.) — US 1 to CT 15', restriction: 'Restricted'),
    ],
  ),
  'DE': _StateDirectoryRecord(
    stateCode: 'DE',
    clearances: const [
      _ClearanceItem(route: 'DE 52 (Pennsylvania Ave.)', location: 'Wilmington, 0.75 mi. west of jct. I-95', height: "13'5\""),
      _ClearanceItem(route: 'DE 100 (Montchanin Rd.)', location: 'Winterthur', height: "12'0\""),
      _ClearanceItem(route: 'Local Road 336D', location: 'Stanton, 1 mi. south', height: "9'10\""),
      _ClearanceItem(route: '14th St.', location: 'Wilmington, at N. Scott St.', height: "13'1\""),
      _ClearanceItem(route: '18th St.', location: 'Wilmington, just south of Augustine Cut-off', height: "12'6\""),
      _ClearanceItem(route: 'Barley Mill Rd.', location: 'Ashland, covered bridge at Red Clay Creek', height: "11'3\""),
      _ClearanceItem(route: 'Beech St.', location: 'Wilmington, at N. Coleman St.', height: "12'6\""),
      _ClearanceItem(route: 'Casho Mill Rd.', location: 'Newark, between DE 2 and DE 273', height: "8'7\""),
      _ClearanceItem(route: 'Central Ave.', location: 'Laurel', height: "12'5\""),
      _ClearanceItem(route: 'Foxhill Ln.', location: 'Wooddale, between DE 48 and Barley Mill Rd.', height: "13'0\""),
      _ClearanceItem(route: 'French St.', location: 'Wilmington, just south of E. Front St.', height: "13'2\""),
      _ClearanceItem(route: 'Gilpin Ave.', location: 'Wilmington, just south of N. Dupont St.', height: "12'0\""),
      _ClearanceItem(route: 'James St.', location: 'Newport, 0.1 mi. south of jct. DE 4', height: "12'10\""),
      _ClearanceItem(route: 'Lovering Ave.', location: 'Wilmington, at Augustine Cut Off', height: "12'6\""),
      _ClearanceItem(route: 'Lovers Ln.', location: 'Kirkwood, 0.75 mi. north, west of DE 71', height: "12'0\""),
      _ClearanceItem(route: 'North Chapel St.', location: 'Newark', height: "12'8\""),
      _ClearanceItem(route: 'Old Ogletown Rd.', location: 'DE 273 to Augusta Dr.', height: "12'0\""),
      _ClearanceItem(route: 'Rising Sun Ln.', location: 'Wilmington, between DE 52 & DE 141', height: "13'6\""),
      _ClearanceItem(route: 'Smith Bridge Rd.', location: 'Wilmington, at Brandywine Creek', height: "11'0\""),
      _ClearanceItem(route: 'Telegraph Rd.', location: 'Stanton, 0.5 mi. west', height: "10'8\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'US 13', location: 'Smyrna — 5 mi. north', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 301', location: 'Middletown — just east of Maryland state line', direction: 'NB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'DE 2/4 (Christina Pkwy.) — DE 2 Bus. to S. College Ave.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'DE 6 — DE 1 to DE 9', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 13 — Laurel, over Broad Creek', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 13 (E. 4th St.) — Wilmington, DE 9 to N. Church St.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 13 Bus. (S. Walnut St.) — Wilmington, A St. to E. 4th St.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'DE 17 — DE 26 to Roxana', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'DE 82 — DE 52 to Pennsylvania state line', restriction: 'Restricted'),
    ],
  ),
  'DC': _StateDirectoryRecord(
    stateCode: 'DC',
    clearances: const [
      _ClearanceItem(route: 'Florida Ave.', location: '1 block south of US 50', height: "13'6\""),
      _ClearanceItem(route: 'L St.', location: 'East of 1st St., under Washington Terminal Yards', height: "13'6\""),
      _ClearanceItem(route: 'M St.', location: 'East of 1st St., under Washington Terminal Yards', height: "13'6\""),
      _ClearanceItem(route: 'Connecticut Ave.', location: 'Q St. underpass, near New Hampshire Ave.', height: "13'6\""),
      _ClearanceItem(route: 'Massachusetts Ave.', location: 'Underpass at Thomas Circle', height: "12'6\""),
      _ClearanceItem(route: 'Potomac River Fwy.', location: 'US 50, Theodore Roosevelt Bridge', height: "13'0\""),
      _ClearanceItem(route: 'South Capitol St.', location: 'South of Virginia Ave.', height: "13'1\""),
      _ClearanceItem(route: '2nd St.', location: 'Underpass at Virginia Ave.', height: "13'6\""),
      _ClearanceItem(route: '3rd St.', location: 'Underpass at Virginia Ave.', height: "13'5\""),
      _ClearanceItem(route: '7th St.', location: 'Underpass at Virginia Ave.', height: "13'6\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-295', location: 'Near Maryland state line', direction: 'SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'All National Park Service roads', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 50 — US 1 to Virginia state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'I-66 — Theodore Roosevelt Memorial Bridge to US 50', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: '9th St. NE — Over New York Ave.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: '17th St. NW/SW — H St. to Independence Ave. SW', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: '27th St. NW — Over Broad Branch', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: '31st St. NW — Over C&O Canal', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'Kenilworth Ter. NE — Over Watts Branch', restriction: 'Restricted'),
    ],
  ),
  'FL': _StateDirectoryRecord(
    stateCode: 'FL',
    clearances: const [
      _ClearanceItem(route: 'FL 600', location: 'Lakeland', height: "13'6\""),
      _ClearanceItem(route: '16th St.', location: 'Miami Beach, FL 907/Alton Rd.', height: "11'10\""),
      _ClearanceItem(route: 'Bloxham St.', location: 'Tallahassee, FL 61 overpass', height: "12'6\""),
      _ClearanceItem(route: 'College St.', location: 'Jacksonville, I-95 overpass', height: "12'8\""),
      _ClearanceItem(route: 'Gadsden St.', location: 'Tallahassee, US 27 overpass', height: "13'0\""),
      _ClearanceItem(route: 'Washington St.', location: 'Lake City, US 41 overpass', height: "12'6\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'US 1', location: 'Bunnell', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 1', location: 'Boulogne — 2.5 mi. south of GA state line', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 1', location: 'Plantation Key', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-4', location: 'Seffner', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Ellaville', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Pensacola — 3 mi. east of AL state line', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Sneads — west of exit 158', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 17', location: 'East Palatka', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 17', location: 'Yulee — south of jct. I-95, 3 mi. south of GA line', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 19', location: 'Old Town', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 27/129', location: 'Branford — just west of east jct. with US 129', direction: 'Both', poe: null),
      _WeighStationItem(highway: 'FL 60', location: 'Hopewell — at FL 39', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'Port Charlotte — 5.1 mi. south of jct. US 17', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'White Springs', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'Wildwood — 9 mi. north of FL 44', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Pensacola — west of US 90 Alt.', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Flagler Beach', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Hobe Sound', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Palm City — MP 113', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Yulee — south of jct. US 17', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'FL 121', location: 'Macclenny', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 441', location: 'Lake City — north', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'FL 105/A1A — American Beach to FL 105', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 27 — Ash St. through Perry', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 441 — FL 100A to US 41 through Lake City', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'FL 922/Broad Cswy. — US 1 to Bay Harbor Islands', restriction: 'Restricted'),
    ],
  ),
  'GA': _StateDirectoryRecord(
    stateCode: 'GA',
    clearances: const [
      _ClearanceItem(route: 'GA 2', location: 'Ringgold', height: "11'7\""),
      _ClearanceItem(route: 'GA 12', location: 'Warrenton', height: "13'6\""),
      _ClearanceItem(route: 'US 23/29/78', location: 'Druid Hills', height: "10'0\""),
      _ClearanceItem(route: 'GA 44', location: 'Union Point', height: "13'6\""),
      _ClearanceItem(route: 'GA 92', location: 'Fairburn, SE of US 29', height: "10'0\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-16', location: 'Blitchton — MP 144', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-20', location: 'Bremen — 3.8 mi east of US 27 — MP 15', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-20', location: 'Grovetown — MP 187.5', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-20', location: 'Grovetown — MP 187.8', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-20', location: 'Lithia Springs — MP 43', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'Forsyth — 1.2 mi N of exit — MP 190', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'Ringgold — 0.5 mi S of exit — MP 343', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'Valdosta — 1.6 mi N of exit — MP 23', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 84', location: 'Ludowici — south', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-85', location: 'La Grange — MP 22.5', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-85', location: 'Lavonia — 2.3 mi S of GA 17 — MP 171', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-85', location: 'Lavonia — 3.5 mi S — MP 169', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Darien — 6.1 mi N of exit — MP 54', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Port Wentworth — MP 111', direction: 'SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'Atlanta — within I-285 loop', restriction: 'All Interstate, U.S., and State highways restricted'),
      _RestrictedRouteItem(designation: 'Newnan — all through routes', restriction: 'Prohibited'),
      _RestrictedRouteItem(designation: 'GA 45 — GA 41 to GA 234', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'GA 136 — GA 9 to US 19', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'GA 216 — Milford to GA 37', restriction: 'Restricted'),
    ],
  ),
  'HI': _StateDirectoryRecord(
    stateCode: 'HI',
    clearances: const [
      _ClearanceItem(route: 'HI 63', location: 'Honolulu — 1.5 mi west of I-H3', height: "13'0\""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'Oahu', location: 'Honolulu — Sand Island Access Rd.', direction: 'Both', poe: null),
      _WeighStationItem(highway: 'HI 19', location: 'Hilo — MP 0 (POE)', direction: 'Both', poe: 'POE (portable scales may be used)'),
      _WeighStationItem(highway: 'HI 270', location: 'Kawaihae — MP 3.4 (POE)', direction: 'Both', poe: 'POE (portable scales may be used)'),
      _WeighStationItem(highway: 'HI 51', location: 'Lihue — MP 0 (POE)', direction: 'Both', poe: 'POE (portable scales may be used)'),
      _WeighStationItem(highway: 'HI 32', location: 'Kahului — MP 2.8 (POE)', direction: 'Both', poe: 'POE (portable scales may be used)'),
      _WeighStationItem(highway: 'HI 64', location: 'Honolulu — Sand Island Access Rd. — MP 0 (POE)', direction: 'Both', poe: 'POE (portable scales may be used)'),
    ],
    restricted: const [
      // None reported
    ],
  ),
  'ID': _StateDirectoryRecord(
    stateCode: 'ID',
    clearances: const [
      _ClearanceItem(route: 'US 20/26 Bus. SB', location: 'Idaho Falls — MP 333.48', height: "13'8""),
      _ClearanceItem(route: 'US 20/26 Bus. NB', location: 'Idaho Falls — MP 333.49', height: "14'0""),
      _ClearanceItem(route: 'US 30', location: 'Pocatello — MP 334.14', height: "13'7""),
      _ClearanceItem(route: 'US 95 Bus.', location: 'Craigmont', height: "14'0""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'US 2/95', location: 'Bonners Ferry — north — MP 510.6', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 12/95', location: 'Lewiston — MP 309.79', direction: 'Both', poe: null),
      _WeighStationItem(highway: 'US 12/95', location: 'Lewiston Hill — north — MP 317.9', direction: 'Both', poe: null),
      _WeighStationItem(highway: 'I-15', location: 'Inkom — 14 mi SE of Pocatello — MP 59.01', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-15', location: 'Sage Junction — 6 mi S of Hamer — MP 141.86', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 20', location: 'Ashton — 4.5 mi SW', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'ID 55', location: 'Horseshoe Bend — MP 65.38', direction: 'Both', poe: null),
      _WeighStationItem(highway: 'I-84', location: 'Boise — SE — MP 67', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-84', location: 'Cotterel — ~7 mi S of I-86 — MP 229.02', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-90', location: 'Haugan, MT — 15 mi E of ID line (joint port with MT)', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-90', location: 'Huetter — 3.5 mi W of US 95 — MP 8.15', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 93', location: 'Hollister — MP 26.16', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 95', location: 'Marsing — MP 26.26', direction: 'Both', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'ID 11 — US 12 to Headquarters', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ID 14 — ID 13 to Elk City', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ID 21 — Idaho City to Stanley', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ID 29 — Leadore to Montana state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ID 57 — US 2 to Nordman', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ID 71 — Cambridge to Oregon state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ID 97 — I-90 to ID 3', restriction: 'Restricted'),
    ],
  ),
  'IL': _StateDirectoryRecord(
    stateCode: 'IL',
    clearances: const [
      _ClearanceItem(route: 'IL 1 NB/SB', location: 'Crete — 4.78 mi north of jct. IL 394', height: "13'8""),
      _ClearanceItem(route: 'US 6 WB', location: 'Joliet — 0.6 mi east of IL 53', height: "13'3""),
      _ClearanceItem(route: 'IL 7/53 NB', location: 'Crest Hill — 0.76 mi north of IL 53 south jct.', height: "12'6""),
      _ClearanceItem(route: 'US 14 EB (Peterson Av.)', location: 'Chicago — 0.25 mi east of Western Av.', height: "12'6""),
      _ClearanceItem(route: 'US 14 WB (Peterson Av.)', location: 'Chicago — 0.75 mi east of Western Av.', height: "12'6""),
      _ClearanceItem(route: 'IL 14', location: 'McLeansboro — west of IL 142', height: "13'6""),
      _ClearanceItem(route: 'IL 19 EB/WB (Irving Park Rd.)', location: 'Chicago — at US 41 overpass', height: "12'6""),
      _ClearanceItem(route: 'IL 19 EB (Irving Park Rd.)', location: 'Chicago — between IL 50 & I-90/94', height: "13'6""),
      _ClearanceItem(route: 'IL 19 WB (Irving Park Rd.)', location: 'Chicago — between IL 50 & I-90/94', height: "13'6""),
      _ClearanceItem(route: 'US 24 Bus.', location: 'Washington — 2.43 mi east of IL 8', height: "13'0""),
      _ClearanceItem(route: 'IL 25 SB (Broadway)', location: 'Aurora — 0.3 mi south of New York St.', height: "13'0""),
      _ClearanceItem(route: 'IL 25 NB', location: 'Montgomery — 0.5 mi south of US 30', height: "12'11""),
      _ClearanceItem(route: 'US 150', location: 'Chrisman — just west of US 150', height: "13'1""),
      _ClearanceItem(route: 'US 45/52 EB/WB', location: 'Kankakee — 0.1 mi east of IL 115', height: "12'8""),
      _ClearanceItem(route: 'US 45/150 NB/SB (Springfield Av.)', location: 'Champaign — 0.1 mi east of Neil St.', height: "12'6""),
      _ClearanceItem(route: 'IL 50 (Cicero Av.)', location: 'Chicago — 0.4 mi north of I-90', height: "13'2""),
      _ClearanceItem(route: 'IL 50 NB/SB (Cicero Av.)', location: 'Chicago — just south of I-90', height: "13'0""),
      _ClearanceItem(route: 'US 51 Bus. SB', location: 'Decatur — 0.1 mi north of US 36', height: "13'5""),
      _ClearanceItem(route: 'IL 53 NB (N. Scott St.)', location: 'Joliet — 0.49 mi north of US 30', height: "12'10""),
      _ClearanceItem(route: 'IL 64 EB/WB (North Av.)', location: 'Chicago — just east of I-90/94', height: "12'6""),
      _ClearanceItem(route: 'IL 78', location: 'Jacksonville — 3.65 mi north of US 67', height: "13'6""),
      _ClearanceItem(route: 'IL 78', location: 'Laura — 1.26 mi north of US 150', height: "13'6""),
      _ClearanceItem(route: 'IL 82 NB/SB', location: 'Geneseo — 0.5 mi north of US 6', height: "9'10""),
      _ClearanceItem(route: 'IL 90/91', location: 'Princeville — 4.1 mi east of IL 90', height: "13'6""),
      _ClearanceItem(route: 'IL 94', location: 'Golden — 3.5 mi north of US 24', height: "13'6""),
      _ClearanceItem(route: 'IL 94', location: 'Stronghurst — 1.5 mi south of IL 116', height: "13'1""),
      _ClearanceItem(route: 'IL 104', location: 'Trees Station — NW of Franklin', height: "13'4""),
      _ClearanceItem(route: 'IL 167 EB/WB', location: 'Wataga — east of US 34', height: "13'4""),
      _ClearanceItem(route: 'IL 180', location: 'Williamsfield — 1.31 mi north of US 150', height: "13'3""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'US 12', location: 'Richmond — 1 mi north of IL 173', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 14', location: 'Harvard — 3 mi north', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 24/52', location: 'Sheldon — 1.5 mi east of IN state line', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 30', location: 'Chicago Heights — at Torrence Av.', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 30', location: 'Compton — west of I-39/US 51 — at jct. IL 251', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 36/54', location: 'Pittsfield — west city limits', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 41', location: 'Rosecrans — 0.25 mi north of IL 173', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 41', location: 'Wadsworth — 2.2 mi south of IL 173', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Bolingbrook — west of IL 53 — MP 265.5', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Litchfield — 3 mi north of IL 16 — MP 56.5', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Williamsville — 2 mi south — MP 114', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-55/70', location: 'Maryville — 1 mi west of IL 159 — MP 14', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-57', location: 'Marion — 7 mi south of IL 13 — MP 47', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-57', location: 'Peotone — approx. 3 mi north — MP 330', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-64', location: "O'Fallon — 1 mi west of US 50 & IL 158 — Exit 19A-B — MP 18", direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Brownstown — 8.8 mi east of US 51 — MP 71', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Marshall — 5 mi east of IL 1 — MP 151', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'NE of Marshall — 4.95 mi west of IN state line', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-74', location: 'Carlock — 2.5 mi southeast — MP 122', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-74/280', location: 'Moline — 1.5 mi east of US 150 — MP 5.5', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-74/280', location: 'Moline — 3.5 mi east of US 150 — MP 6.5', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'East Moline — 2 mi south of IA state line — MP 2', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Mokena — 1.5 mi west of US 45 — MP 143', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Mokena — 1.5 mi east of US 45 — MP 147', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'IL 83', location: 'Villa Park — at St. Charles Rd.', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'All boulevards in Chicago', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'IL 8/29/116 — Peoria over Illinois River to East Peoria', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'IL 9 — Niota over Mississippi River to IA state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 20/45 — Cermak Rd. (Westchester) to Joliet Rd. (Countryside)', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 41 — Chicago — Jeffery Ave. to US 12/20', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 41 — Gurnee — US 41 ramp to IL 132 EB (max length 50’)', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'IL 64 (North Av.) — Elmhurst — IL 83 to I-290', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'IL 113 — I-55 to Braidwood', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'Green Bay Rd. — Evanston — McCormick Blvd. to Highwood', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'Lake Shore Dr. — Chicago — Sheridan Rd. to Marquette Dr.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'Sheridan Rd. — Chicago — US 14 to Highland Park', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'Washington Blvd. — US 20/20 (Bellwood) to 1st Av. (Maywood)', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'Washington Blvd. — IL 43 (Forest Park)', restriction: 'Restricted'),
    ],
  ),
  'IN': _StateDirectoryRecord(
    stateCode: 'IN',
    clearances: const [
      _ClearanceItem(route: 'IN 17', location: 'Plymouth — 1.7 mi. south of US 30', height: "10'11""),
      _ClearanceItem(route: 'US 150', location: 'Ferguson Hill — 1.94 mi. north of US 40', height: "12'10""),
      _ClearanceItem(route: 'US 231', location: 'St. John — 0.23 mi. south of jct. US 41', height: "13'6""),
      _ClearanceItem(route: 'IN 450 EB', location: 'Williams — 8.3 mi. west of IN 158', height: "12'11""),
      _ClearanceItem(route: 'IN 450 WB', location: 'Williams — 8.3 mi. west of IN 158', height: "13'2""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-65', location: 'Lowell — 0.5 mi. north of IN 2', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-69', location: 'Warren — 0.25 mi. north of IN 124', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Richmond — 1.03 mi. west of US 35', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Terre Haute — just east of Illinois state line', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-74', location: 'West Harrison — at Ohio state line', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-94', location: 'NE of Chesterton — 5.7 mi. west of jct. US 421', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-94', location: 'NE of Chesterton — 5.7 mi. west of jct. US 421', direction: 'WB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'IN 46 — Bowling Green — over Eel River', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'IN 62 — IN 250 to Dillsboro', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'IN 550 — Loogootee to Lacy', restriction: 'Restricted'),
    ],
  ),
  'IA': _StateDirectoryRecord(
    stateCode: 'IA',
    clearances: const [
      _ClearanceItem(route: 'IA 14', location: 'Corydon — north', height: "Actual 13'6"", mapKey: null),
      _ClearanceItem(route: 'US 61 Bus. NB (Brady St.)', location: 'Davenport — 0.1 mi. north of 4th St.', height: "Actual 12'0""),
      _ClearanceItem(route: 'US 61 Bus. SB (Harrison St.)', location: 'Davenport — 0.3 mi. north of US 61/67 (River Dr.)', height: "Actual 12'1""),
      _ClearanceItem(route: 'US 75', location: 'Hull — 1.4 mi. north of jct. US 18', height: "Actual 13'9""),
      _ClearanceItem(route: 'IA 163 WB (E. University Av.)', location: 'Des Moines — 0.09 mi. west of E 21st St.', height: "Actual 13'9""),
      _ClearanceItem(route: 'IA 415 NB (2nd Av.)', location: 'Des Moines — 0.9 mi. south of I-35/80', height: "Actual 13'8""),
      _ClearanceItem(route: 'IA 415 SB (2nd Av.)', location: 'Des Moines — 0.9 mi. south of I-35/80', height: "Actual 13'8""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-29', location: 'Percival — 1.5 mi. north of IA 2', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-29', location: 'Salix — 1.5 mi. south of Exit 134', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-35', location: 'Ames — 3 mi. north of IA 210 & Exit 102', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-35', location: 'Northwood — south of Exit 214', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-35', location: 'Osceola — south of Exit 33', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 71', location: 'Early — north of jct. US 20', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Mitchellville — east at MP 151', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Van Meter — at MP 115', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-80', location: 'Walnut', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'US 218', location: 'Mt. Pleasant — south of jct. with IA 16', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-380', location: 'Brandon', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'IA 9 — Fort Madison — over Mississippi River to IL state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'IA 175 — I-29 to Nebraska state line', restriction: 'Restricted'),
    ],
  ),
  'KS': _StateDirectoryRecord(
    stateCode: 'KS',
    clearances: const [
      _ClearanceItem(route: 'KS 31', location: 'Kincaid — 0.5 mi. east', height: "14'0""),
      _ClearanceItem(route: 'KS 32', location: 'Wyandotte — under WB Turner Diagonal Fwy.', height: "13'9""),
      _ClearanceItem(route: 'US 40/S9', location: 'Lawrence — 1 mi. south of jct. I-70', height: "14'0""),
      _ClearanceItem(route: 'US 59', location: 'Garnett — 1.0 mi. south', height: "14'0""),
      _ClearanceItem(route: 'KS 147', location: 'Cedar Bluff Reservoir Spillway', height: "14'0""),
      _ClearanceItem(route: 'KS 147', location: 'Ogallah — under EB I-70', height: "13'9""),
      _ClearanceItem(route: 'KS 147', location: 'Ogallah — under WB I-70', height: "14'0""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-35', location: 'Olathe — 5 mi. south', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-35', location: 'South Haven', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 54', location: 'Liberal — 5 mi. east — MP 11.5', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Kanorado — near CO state line', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-70', location: 'Wabaunsee — 2 mi. east of KS 99', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 81', location: 'Belleville — 1 mi. south of US 36', direction: 'SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'KS 23 — 2.28 mi. south of US 54 (Meade) — Entrance', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 36 — Smith Center to KS 181', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 166 — Chetopa to Melrose', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 183 — US 54 to Coldwater', restriction: 'Restricted'),
    ],
  ),
  'KY': _StateDirectoryRecord(
    stateCode: 'KY',
    clearances: const [
      _ClearanceItem(route: 'KY 7', location: 'Colson — 3 mi. east', height: "12'10""),
      _ClearanceItem(route: 'KY 8 (4th St.)', location: 'Newport & Covington — Licking River bridge', height: "13'6""),
      _ClearanceItem(route: 'KY 9', location: 'Newport — south of 12th St.', height: "13'4""),
      _ClearanceItem(route: 'KY 17 (Greenup St.)', location: 'Covington — near 17th St.', height: "13'0""),
      _ClearanceItem(route: 'KY 26', location: 'Woodbine — 3 mi. southwest', height: "12'0""),
      _ClearanceItem(route: 'US 27 (Broadway)', location: 'Lexington — 0.1 mi. SE of KY 4', height: "13'2""),
      _ClearanceItem(route: 'US 45', location: 'Paducah — Irvin S. Cobb Bridge', height: "13'0""),
      _ClearanceItem(route: 'KY 632', location: 'Coleman — 2.6 mi. west of KY 194', height: "12'0""),
      _ClearanceItem(route: 'KY 1031', location: 'Central City — 0.1 mi. south of KY 70', height: "11'4""),
      _ClearanceItem(route: 'KY 1571', location: 'Ravenna', height: "11'2""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'US 23/460', location: 'Prestonsburg — north of KY 3', direction: 'Both', poe: null),
      _WeighStationItem(highway: 'I-24', location: 'Eddyville — west of MP 36', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 41', location: 'Henderson — north of MP 21', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 51', location: 'Fulton — just north of TN state line', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-64', location: 'Morehead — east of MP 148', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-64', location: 'Shelbyville — east of MP 38.5', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-65', location: 'Elizabethtown — south of MP 90', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-65', location: 'Franklin — southeast of MP 4', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-71', location: 'Walton — south of MP 76', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'Georgetown — north of MP 130', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'London — 5 mi. south — MP 33', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'I-75', location: 'Walton — south of MP 168.8', direction: 'SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'A Highways', restriction: '44,000 lbs limit'),
      _RestrictedRouteItem(designation: 'AA Highways', restriction: '62,000 lbs limit'),
      _RestrictedRouteItem(designation: 'KY 1 — KY 7 to US 23', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'KY 2 — I-64 to US 23', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'KY 62 — US 27 to US 68', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'KY 80 — US 421 to Virginia state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 460 — Shelbiana to Virginia state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 467 — US 127 to I-75', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'National Park Rd. — Mammoth Cave', restriction: 'Restricted'),
    ],
  ),
  'LA': _StateDirectoryRecord(
    stateCode: 'LA',
    clearances: const [
      _ClearanceItem(route: 'LA 1 Bus.', location: 'Natchitoches', height: "13'3""),
      _ClearanceItem(route: 'LA 8', location: 'Burr Ferry — Sabine River bridge (curb)', height: "12'3""),
      _ClearanceItem(route: 'LA 15', location: 'Alto — Boeuf River bridge (curb)', height: "13'2""),
      _ClearanceItem(route: 'US 90 (Broad Ave.)', location: 'New Orleans — 0.2 mi. south of I-610', height: "13'4""),
      _ClearanceItem(route: 'LA 165 Bus.', location: 'Pineville', height: "11'10""),
      _ClearanceItem(route: 'US 171 NB', location: 'Leesville', height: "13'6""),
      _ClearanceItem(route: 'LA 538', location: 'Mooringsport — 4.75 mi. southeast', height: "13'3""),
      _ClearanceItem(route: 'LA 729', location: 'Lafayette — west of US 90, near Regional Airport', height: "12'4""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'I-10', location: 'Breaux Bridge — 2 mi. west of interchange', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Laplace — 1 mi. west of US 51', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: '1 mi. east of Mississippi state line (joint with MS)', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Toomey', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-12', location: 'Hammond — 1 mi. west of I-55', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-12', location: 'Starks — west of LA 109', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-20', location: 'Delta — 1 mi. west of Mississippi River', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-20', location: 'Greenwood — 2 mi. east of Texas state line', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Kentwood', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-55', location: 'Nicholson, MS — 1 mi. north of MS state line', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-10', location: 'Laplace — 2 mi. east of US 51', direction: 'EB/WB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'LA 4 — LA 147 to LA 34', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'LA 8 — US 190 to LA 77', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'LA 14 — US 167 to LA 82', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'LA 92 — US 167 to Milton', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'LA 104 — US 13 to Point Blue', restriction: 'Restricted'),
    ],
  ),
  'ME': _StateDirectoryRecord(
    stateCode: 'ME',
    clearances: const [
      _ClearanceItem(route: 'ME 9', location: 'Saco — MP 39.3', height: "Min 12'1"", mapKey: null),
      _ClearanceItem(route: 'ME 24', location: 'Richmond — MP 34.9', height: "Min 11'2"", mapKey: null),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'US 1', location: 'Caribou — south', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 1', location: 'Ellsworth — 2 mi. west', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 1', location: 'Houlton — near Littleton-Houlton town line', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 1', location: 'Kittery — 3 mi. north of NH line', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 1', location: 'Presque Isle', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 1/ME 6', location: 'Topsfield — just south of ME 6', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 2', location: 'Rumford — west', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'ME 4', location: 'Wilton — north of ME 156', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'ME 9', location: 'Hancock–Washington County line', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Houlton — U.S. Border Port of Entry', direction: 'SB', poe: 'POE'),
      _WeighStationItem(highway: 'I-95', location: 'Kittery — 3 mi. north of NH state line', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 1', location: 'Old Town', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 201', location: 'Hinckley', direction: 'NB', poe: null),
      _WeighStationItem(highway: 'US 201', location: 'Jackman — south of Canadian border', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 202/ME 9', location: 'Unity', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'US 1 — Kittery over Piscataqua River', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ME 3 — Bar Harbor to ME 233', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ME 24 — Bailey Island to Orrs Island', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ME 104 (Water St.) — US 201 to ME 3', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ME 153 — North Parsonsfield — NH line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'ME 180 — ME 179 to ME 181', restriction: 'Restricted'),
    ],
  ),
  'MD': _StateDirectoryRecord(
    stateCode: 'MD',
    clearances: const [
      _ClearanceItem(route: 'MD 7B', location: 'Perryville', height: "13'6""),
      _ClearanceItem(route: 'MD 7C', location: 'North East', height: "11'2""),
      _ClearanceItem(route: 'MD 36', location: 'Frostburg', height: "12'0""),
      _ClearanceItem(route: 'MD 51', location: 'Near West Virginia border', height: "11'8""),
      _ClearanceItem(route: 'MD 75', location: 'Monrovia', height: "12'6""),
      _ClearanceItem(route: 'MD 117', location: 'Boyds', height: "12'6""),
      _ClearanceItem(route: 'MD 222', location: 'Port Deposit', height: "12'6""),
      _ClearanceItem(route: 'MD 303', location: 'Cordova', height: "12'6""),
      _ClearanceItem(route: 'MD 831A', location: 'Homewood — bypass jct. US 40/MD 36', height: "Min 10'9""),
    ],
    weighStations: const [
      _WeighStationItem(highway: 'US 1', location: 'Darlington — 2 mi. south of Susquehanna Dam crossing', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 13', location: 'Delmar — south of DE line', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 40', location: 'Thomas J. Hatem Memorial Bridge', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'US 50', location: 'William Preston Lane Jr. Memorial Bridge', direction: 'EB/WB', poe: null),
      _WeighStationItem(highway: 'I-68', location: 'Midlothian — midway between exits 29 & 33', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-70/US 40', location: 'New Market — 1.5 mi. east of MD 75', direction: 'EB', poe: null),
      _WeighStationItem(highway: 'I-70/US 40', location: 'West Friendship — west of MD 32 (Exit 80)', direction: 'WB', poe: null),
      _WeighStationItem(highway: 'I-83', location: 'Parkton — south of Exit 36', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'I-95', location: 'Tydings Memorial Bridge — toll plaza', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'I-270', location: 'Hyattstown — at Frederick/Montgomery Co. line — MP 22', direction: 'NB/SB', poe: null),
      _WeighStationItem(highway: 'US 301', location: 'Cecilton — at jct. MD 299', direction: 'SB', poe: null),
      _WeighStationItem(highway: 'US 301', location: 'Upper Marlboro — north of MD 4', direction: 'NB/SB', poe: null),
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'I-895 Harbor Tunnel Thruway', restriction: 'Hazardous restrictions'),
      _RestrictedRouteItem(designation: 'US 13 Bus. — Pocomoke City — over Pocomoke River', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MD 25 — MD 137 to MD 88', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MD 68 — Breathesville to US 40 Alt.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MD 75 — Monrovia — Baldwin Rd. to MD 80', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MD 190 — I-495 to Washington D.C. line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MD 295 (Baltimore–Washington Pkwy.) — US 50 to MD 175', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'Suitland Pkwy. — DC line to MD 4', restriction: 'Restricted'),
    ],
  ),
  'MA': _StateDirectoryRecord(
    stateCode: 'MA',
    clearances: const [
      _ClearanceItem(route: 'US 1', location: 'Newburyport — at MA 1A (High St.)', height: "13'6""),
      _ClearanceItem(route: 'US 1', location: 'Westwood', height: "13'5""),
      _ClearanceItem(route: 'MA 2', location: 'Boston — underpass at jct. MA 2A', height: "12'6""),
      _ClearanceItem(route: 'MA 3 NB', location: 'Boston — 0.4 mi. south of jct. MA 28', height: "10'8""),
      _ClearanceItem(route: 'MA 3 SB', location: 'Cambridge — south of Longfellow Bridge', height: "11'11""),
      _ClearanceItem(route: 'MA 3 (Memorial Dr.)', location: 'Cambridge — express underpass at MA 2A', height: "9'0""),
      _ClearanceItem(route: 'MA 28 SB', location: 'Somerville — 0.4 mi. south of I-93', height: "13'5""),
      _ClearanceItem(route: 'MA 35', location: 'Danvers — at MA 128 overpass', height: "12'4""),
      _ClearanceItem(route: 'MA 62', location: 'Concord', height: "12'6""),
      _ClearanceItem(route: 'MA 152', location: 'Attleboro — 0.2 mi. south of MA 123', height: "12'4""),
      _ClearanceItem(route: 'US 202', location: 'Westfield — north of Westfield River', height: "13'6""),
    ],
    weighStations: const [
      // None reported (Massachusetts uses portable scales only)
    ],
    restricted: const [
      _RestrictedRouteItem(designation: 'MA 1A — Rowley to Newbury', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MA 4 — MA 225 to I-95', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 5 — MA 10 to Vermont state line', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MA 20 — US 20 to Becket Center', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MA 66 — Westhampton — over Sodom Brook', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MA 110 — Lawrence to I-495', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'MA 152 — Thacher St. to Riverside Av.', restriction: 'Restricted'),
      _RestrictedRouteItem(designation: 'US 202 — US 20 to MA 57', restriction: 'Restricted'),
    ],
  ),
*/
};

final _onTheRoadProvider = Provider<Map<String, _StateDirectoryRecord>>((ref) {
  return _onTheRoadSeed; // future: fetch from backend or cache
});

// Cards for modules (lightweight content, RoadDogg embedded)
class _InspectionProcedureCard extends StatelessWidget {
  const _InspectionProcedureCard();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tractor/Trailer Inspection — 19-step',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Walkaround: Left Cab → Front → Right → Fuel Tanks → Coupling → Rear Tractor → Trailer Wheels → Inside Cab → Brakes.',
            ),
            SizedBox(height: 6),
            Text('Emergency equipment: fuses, triangles, extinguisher.'),
            SizedBox(height: 6),
            Text('Available offline.'),
          ],
        ),
      ),
    );
  }
}

class _FuelTaxBasicsCard extends StatelessWidget {
  const _FuelTaxBasicsCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_gas_station_outlined),
        title: const Text('Fuel Tax Basics & IFTA'),
        subtitle: const Text(
          'State rates, IFTA participation, trip permits. Ask: “Trip permit rule in Maine?”',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _CrossBorderQuickCheckCard extends StatelessWidget {
  const _CrossBorderQuickCheckCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.public),
        title: const Text('Cross-Border Quick Check (MX/CA)'),
        subtitle: const Text(
          'Driver requirements, docs, insurance. Offline checklist ready.',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _OfflineCacheBanner extends ConsumerWidget {
  const _OfflineCacheBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(referenceCacheProvider);
    final ts = cache.lastSyncedAt;
    final text = ts == null
        ? 'Offline mode ready — no sync yet. Data will be cached for offline use.'
        : 'Offline mode — last synced ${ts.toLocal()}';
    return Card(
      color: Colors.indigo.shade50,
      child: ListTile(
        leading: const Icon(Icons.offline_pin_outlined),
        title: const Text('Offline Reference Cache (MVP)'),
        subtitle: Text(text),
        trailing: TextButton.icon(
          icon: const Icon(Icons.sync),
          label: const Text('Sync Now'),
          onPressed: () {
            ref.read(referenceCacheProvider.notifier).state = cache.copyWith(
              lastSyncedAt: DateTime.now(),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('References synced for offline use.'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnTheRoadDirectoryCard extends ConsumerStatefulWidget {
  const _OnTheRoadDirectoryCard();
  @override
  ConsumerState<_OnTheRoadDirectoryCard> createState() =>
      _OnTheRoadDirectoryCardState();
}

class _OnTheRoadDirectoryCardState
    extends ConsumerState<_OnTheRoadDirectoryCard>
    with SingleTickerProviderStateMixin {
  static const _prefsPresetsKey = 'routePlanning.presets.v1';
  String _updatedAgoText() {
    final s = _lastUpdated[_state];
    if (s == null) return '';
    try {
      final dt = DateTime.parse(s);
      final days = DateTime.now().difference(dt).inDays;
      return days <= 0
          ? 'Updated today'
          : 'Updated $days day${days == 1 ? '' : 's'} ago';
    } catch (_) {
      return '';
    }
  }

  static const _stateFlags = {
    // states can be: live, qa, hidden; adjust progressively for rollout
    'CA': 'qa',
    'TX': 'qa',
    'FL': 'qa',
    'NY': 'qa',
    'PA': 'qa',
    'IL': 'qa',
    'OH': 'qa',
    // Example hidden state during QA
    'DC': 'hidden',
  };
  static const _lastUpdated = {
    'CA': '2025-08-15',
    'TX': '2025-08-20',
    'FL': '2025-08-10',
    'NY': '2025-07-30',
    'PA': '2025-08-05',
    'IL': '2025-08-12',
    'OH': '2025-08-14',
    'NJ': '2025-07-25',
    'NM': '2025-07-18',
    'NC': '2025-08-01',
    'OR': '2025-08-22',
    'RI': '2025-07-22',
    'SD': '2025-08-02',
  };
  static const _prefsStateKey = 'routePlanning.lastState';
  static const _prefsFiltersKey = 'routePlanning.filters.v1';
  String _state = 'AL';
  late final TabController _tab;
  bool _weighAlertsOn = false;
  String _query = '';
  bool _hazmatOnly = false;
  bool _interstatesOnly = false;
  bool _lowClearanceFocus = false;
  bool _corridorOnly =
      false; // MVP: simple toggle; filters to likely corridor matches
  List<Map<String, dynamic>> _presets = const [];
  String? _selectedPresetName;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // Restore last selected state if available (persisted via shared_preferences)
    _restoreLastState();
    _loadPresets();
  }

  Map<String, dynamic> _currentPresetSnapshot({String? name}) => {
    'name':
        name ?? 'Preset ${DateTime.now().toIso8601String().substring(11, 19)}',
    'state': _state,
    'query': _query,
    'hazmatOnly': _hazmatOnly,
    'interstatesOnly': _interstatesOnly,
    'lowClearanceFocus': _lowClearanceFocus,
    'corridorOnly': _corridorOnly,
  };

  Future<void> _loadPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsPresetsKey) ?? const [];
      final list = raw
          .map((s) {
            try {
              return Map<String, dynamic>.from(_decodeJson(s));
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((m) => m.isNotEmpty)
          .toList();
      if (mounted) setState(() => _presets = list);
    } catch (_) {}
  }

  Future<void> _saveCurrentAsPreset([String? name]) async {
    try {
      final preset = _currentPresetSnapshot(name: name);
      final next = [
        ..._presets.where((p) => p['name'] != preset['name']),
        preset,
      ];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsPresetsKey,
        next.map((m) => _encodeJson(m)).toList(),
      );
      if (mounted) setState(() => _presets = next);
      _logEvent('preset_saved', {'name': preset['name']});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preset saved: ${preset['name']}')),
        );
      }
    } catch (_) {}
  }

  Future<void> _exportCurrent() async {
    final payload = {
      'state': _state,
      'query': _query,
      'hazmatOnly': _hazmatOnly,
      'interstatesOnly': _interstatesOnly,
      'lowClearanceFocus': _lowClearanceFocus,
      'corridorOnly': _corridorOnly,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _logEvent('export_pdf', payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exporting PDF for $_state with current filters…'),
        ),
      );
    }
    // TODO: integrate real PDF generation; include current filters header and a small map snapshot
  }

  void _applyPreset(Map<String, dynamic> p) {
    setState(() {
      _selectedPresetName = p['name'] as String?;
      _state = (p['state'] as String?) ?? _state;
      _query = (p['query'] as String?) ?? '';
      _hazmatOnly = (p['hazmatOnly'] as bool?) ?? false;
      _interstatesOnly = (p['interstatesOnly'] as bool?) ?? false;
      _lowClearanceFocus = (p['lowClearanceFocus'] as bool?) ?? false;
      _corridorOnly = (p['corridorOnly'] as bool?) ?? false;
    });
    _persistState(_state);
    _logEvent('preset_applied', {'name': p['name'] ?? ''});
  }

  Map<String, dynamic> _decodeJson(String s) {
    return (const JsonDecoder()).convert(s) as Map<String, dynamic>;
  }

  String _encodeJson(Map<String, dynamic> m) {
    return const JsonEncoder().convert(m);
  }

  Future<void> _restoreLastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsStateKey);
      final filtersRaw = prefs.getString(_prefsFiltersKey);
      if (filtersRaw != null) {
        try {
          final f = Map<String, dynamic>.from(_decodeJson(filtersRaw));
          _query = (f['query'] as String?) ?? _query;
          _hazmatOnly = (f['hazmatOnly'] as bool?) ?? _hazmatOnly;
          _interstatesOnly =
              (f['interstatesOnly'] as bool?) ?? _interstatesOnly;
          _lowClearanceFocus =
              (f['lowClearanceFocus'] as bool?) ?? _lowClearanceFocus;
          _corridorOnly = (f['corridorOnly'] as bool?) ?? _corridorOnly;
        } catch (_) {}
      }
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _state = saved);
        return;
      }
      // Terminal-aware default: if a terminal is selected, infer state from its city suffix
      final selId = ref.read(selectedTerminalIdProvider);
      final terms = ref.read(terminalsProvider);
      final term = terms.firstWhere(
        (t) => t.id == selId,
        orElse: () => terms.isNotEmpty
            ? terms.first
            : const Terminal(id: '', name: '', city: ''),
      );
      final inferred = _inferStateFromCity(term.city);
      if (inferred != null && inferred.length == 2 && mounted) {
        setState(() => _state = inferred);
      }
    } catch (_) {
      // ignore errors silently for MVP
    }
  }

  String? _inferStateFromCity(String city) {
    final i = city.lastIndexOf(',');
    if (i == -1 || i + 1 >= city.length) return null;
    final st = city.substring(i + 1).trim();
    if (st.length >= 2) return st.substring(st.length - 2).toUpperCase();
    return null;
  }

  Future<void> _persistFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final m = {
        'query': _query,
        'hazmatOnly': _hazmatOnly,
        'interstatesOnly': _interstatesOnly,
        'lowClearanceFocus': _lowClearanceFocus,
        'corridorOnly': _corridorOnly,
      };
      await prefs.setString(_prefsFiltersKey, _encodeJson(m));
    } catch (_) {}
  }

  Future<void> _persistState(String s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsStateKey, s);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_onTheRoadProvider);
    final record = data[_state];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_filled_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'On-the-Road Directory',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Preset dropdown
                if (_presets.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: DropdownButton<String>(
                      hint: const Text('Presets'),
                      value: _selectedPresetName,
                      items: _presets
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p['name'] as String,
                              child: Text(p['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (name) {
                        final p = _presets.firstWhere(
                          (e) => e['name'] == name,
                          orElse: () => const {},
                        );
                        if (p.isNotEmpty) _applyPreset(p);
                      },
                    ),
                  ),
                IconButton(
                  tooltip: 'Save preset',
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: () {
                    _saveCurrentAsPreset();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                  onPressed: _exportCurrent,
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _state,
                  items:
                      const [
                            'CA',
                            'TX',
                            'FL',
                            'NY',
                            'PA',
                            'IL',
                            'OH', // Batch 1 priority
                            'AL',
                            'AK',
                            'AZ',
                            'AR',
                            'CO',
                            'CT',
                            'DE',
                            'DC',
                            'GA',
                            'HI',
                            'ID',
                            'IL',
                            'IN',
                            'IA',
                            'KS',
                            'KY',
                            'LA',
                            'ME',
                            'MD',
                            'MA',
                          ]
                          .where((s) => _stateFlags[s] != 'hidden')
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) {
                    final next = v ?? _state;
                    setState(() => _state = next);
                    _persistState(next);
                    _logEvent('state_selected', {'state': next});
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Last updated: ${_lastUpdated[_state] ?? '—'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Search and quick filters (per state)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search routes, locations, keywords',
                    ),
                    onChanged: (v) {
                      setState(() => _query = v.trim());
                      _persistFilters();
                      _logEvent('search', {'q': _query, 'state': _state});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Low clearance focus'),
                  selected: _lowClearanceFocus,
                  onSelected: (v) {
                    setState(() => _lowClearanceFocus = v);
                    _persistFilters();
                    _logEvent('toggle_low_clearance', {'on': v});
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Hazmat only'),
                  selected: _hazmatOnly,
                  onSelected: (v) {
                    setState(() => _hazmatOnly = v);
                    _persistFilters();
                    _logEvent('toggle_hazmat', {'on': v});
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Interstates only'),
                  selected: _interstatesOnly,
                  onSelected: (v) {
                    setState(() => _interstatesOnly = v);
                    _persistFilters();
                    _logEvent('toggle_interstates_only', {'on': v});
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Presets
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.location_city),
                  label: const Text('Urban-only'),
                  onPressed: () {
                    setState(() {
                      _interstatesOnly = true; // favor interstates in urban
                      _lowClearanceFocus = true; // show lower risks
                      _hazmatOnly = false;
                    });
                    _persistFilters();
                  },
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.local_fire_department_outlined),
                  label: const Text('Hazmat-sensitive'),
                  onPressed: () {
                    setState(() {
                      _hazmatOnly = true;
                      _interstatesOnly = false;
                    });
                    _persistFilters();
                  },
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: const Text('Low-clearance risk'),
                  onPressed: () {
                    setState(() {
                      _lowClearanceFocus = true;
                    });
                    _persistFilters();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Filter by my route'),
                const SizedBox(width: 8),
                Builder(
                  builder: (ctx) {
                    final isPremium = ref.watch(sessionProvider).isPremium;
                    return Tooltip(
                      message: isPremium
                          ? 'Limit results to likely corridor routes'
                          : 'Pro feature: Upgrade to enable corridor filtering',
                      child: Switch(
                        value: _corridorOnly && isPremium,
                        onChanged: isPremium
                            ? (v) {
                                setState(() => _corridorOnly = v);
                                _persistFilters();
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Low Clearances'),
                Tab(text: 'Weigh Stations'),
                Tab(text: 'Restricted Routes'),
              ],
            ),
            SizedBox(
              height: 240,
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildClearances(record),
                  _buildWeighStations(record),
                  _buildRestricted(record),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('Ask RoadDogg'),
                onPressed: () => GoRouter.of(context).push('/roaddogg'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearances(_StateDirectoryRecord? r) {
    if (r == null || r.clearances.isEmpty) {
      return const Center(child: Text('No data yet.'));
    }
    bool passesLowFocus(String h) {
      if (!_lowClearanceFocus) return true;
      final s = h.replaceAll(RegExp(r"[^0-9']"), '');
      // Naive: consider anything with 12' or 11' or 10' as low
      return s.contains("12'") || s.contains("11'") || s.contains("10'");
    }

    final list = r.clearances.where((c) {
      final hay =
          '${_normalizeRouteLabel('${c.route} ${c.location}')} ${_normalizeHeight(c.height)}'
              .toLowerCase();
      final q = _query.toLowerCase();
      final corridorOk =
          !_corridorOnly ||
          hay.contains('i-') ||
          hay.contains('us ') ||
          hay.contains('sr ') ||
          hay.contains('state ');
      return hay.contains(q) && passesLowFocus(c.height) && corridorOk;
    }).toList();
    if (list.isEmpty) return const Center(child: Text('No matches.'));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final c = list[i];
        return ListTile(
          key: ValueKey('${c.route}-${c.location}-${c.height}'),
          leading: const Icon(Icons.height),
          title: Text('${c.route} — ${c.location}'),
          trailing: Wrap(
            spacing: 6,
            children: [
              Chip(label: Text(_normalizeHeight(c.height))),
              if (_updatedAgoText().isNotEmpty)
                Chip(label: Text(_updatedAgoText())),
            ],
          ),
          onLongPress: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Report queued: ${c.route} — ${c.location} (${c.height})',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeighStations(_StateDirectoryRecord? r) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Alerts'),
              Switch(
                value: _weighAlertsOn,
                onChanged: (v) {
                  setState(() => _weighAlertsOn = v);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        v
                            ? 'Weigh station alerts enabled'
                            : 'Weigh station alerts disabled',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: (r == null || r.weighStations.isEmpty)
              ? const Center(child: Text('No data yet.'))
              : Builder(
                  builder: (ctx) {
                    final filtered = r.weighStations.where((w) {
                      final hay =
                          '${_normalizeRouteLabel('${w.highway} ${w.location}')} ${w.direction}'
                              .toLowerCase();
                      final q = _query.toLowerCase();
                      final interstateOk =
                          !_interstatesOnly ||
                          w.highway.trim().toUpperCase().startsWith('I-');
                      final corridorOk =
                          !_corridorOnly ||
                          w.highway.toLowerCase().startsWith('i-') ||
                          w.highway.toLowerCase().startsWith('us ');
                      return hay.contains(q) && interstateOk && corridorOk;
                    }).toList();
                    if (filtered.isEmpty) {
                      return const Center(child: Text('No matches.'));
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final w = filtered[i];
                        return ListTile(
                          key: ValueKey(
                            '${w.highway}-${w.location}-${w.direction}',
                          ),
                          leading: const Icon(Icons.scale_outlined),
                          title: Text('${w.highway} — ${w.location}'),
                          subtitle: Text('Direction: ${w.direction}'),
                          trailing: (_updatedAgoText().isNotEmpty)
                              ? Chip(label: Text(_updatedAgoText()))
                              : null,
                          onLongPress: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Report queued: ${w.highway} — ${w.location} (${w.direction})',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRestricted(_StateDirectoryRecord? r) {
    if (r == null || r.restricted.isEmpty) {
      return const Center(child: Text('No data yet.'));
    }
    final list = r.restricted.where((rr) {
      final hay = '${_normalizeRouteLabel(rr.designation)} ${rr.restriction}'
          .toLowerCase();
      final q = _query.toLowerCase();
      final hazOk =
          !_hazmatOnly || rr.restriction.toLowerCase().contains('hazmat');
      final corridorOk =
          !_corridorOnly || hay.contains('i-') || hay.contains('us ');
      return hay.contains(q) && hazOk && corridorOk;
    }).toList();
    if (list.isEmpty) return const Center(child: Text('No matches.'));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final rr = list[i];
        return ListTile(
          key: ValueKey('${rr.designation}-${rr.restriction}'),
          leading: const Icon(Icons.block, color: Colors.redAccent),
          title: Text(rr.designation),
          subtitle: Text(rr.restriction),
          trailing: Wrap(
            spacing: 6,
            children: [
              const Chip(label: Text('Verified')),
              if (_updatedAgoText().isNotEmpty)
                Chip(label: Text(_updatedAgoText())),
            ],
          ),
          onLongPress: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Report queued: ${rr.designation} — ${rr.restriction}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FuelTaxIfTAPlanningCard extends StatelessWidget {
  const _FuelTaxIfTAPlanningCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.table_chart_outlined),
        title: const Text('Fuel Tax / IFTA Planning'),
        subtitle: const Text(
          'Plan fuel tax across multi-state trips; export compliance reporting.',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _FuelTaxImpactCard extends StatelessWidget {
  const _FuelTaxImpactCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.price_check_outlined),
        title: const Text('Fuel Tax Impact by Lane'),
        subtitle: const Text('Helps pricing/contracts; include in proposals.'),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

// New modules (State Access Policies, LCVs, Weight & Size, Trailer Combinations)
class _StateAccessPoliciesCard extends StatelessWidget {
  const _StateAccessPoliciesCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.signpost_outlined),
        title: const Text('State Access Policies'),
        subtitle: const Text(
          'How far off the National Network you can travel. Quick per-state lookup.',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _LcvRulesCard extends StatelessWidget {
  const _LcvRulesCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.add_road_outlined),
        title: const Text('Longer Combination Vehicles (LCVs)'),
        subtitle: const Text(
          'Doubles/Triples by state; Rocky Mountain vs Turnpike Doubles; Triples.',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _WeightSizeLimitsCard extends StatelessWidget {
  const _WeightSizeLimitsCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.scale_outlined),
        title: const Text('Weight & Size Limits'),
        subtitle: const Text(
          'Axle limits, GVW, width/height/length by state/province.',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _TrailerCombinationLimitsCard extends StatelessWidget {
  const _TrailerCombinationLimitsCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.merge_outlined),
        title: const Text('Trailer Combination Lengths'),
        subtitle: const Text(
          'Combination limits: tractor+semi, twins, triples, A-trains (US/Canada).',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

// Planner variants for Fleet/Broker (with export CTA)
class _StateAccessPoliciesPlannerCard extends StatelessWidget {
  const _StateAccessPoliciesPlannerCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.signpost),
        title: const Text('State Access Policies — Planner'),
        subtitle: const Text(
          'Validate last-mile legality across corridor; export PDF.',
        ),
        trailing: OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exporting State Access report…')),
          ),
        ),
      ),
    );
  }
}

class _LcvPlannerCard extends StatelessWidget {
  const _LcvPlannerCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.add_road),
        title: const Text('LCV Rules — Planner'),
        subtitle: const Text('Flag doubles/triples legality on planned loads.'),
        trailing: OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exporting LCV compliance…')),
          ),
        ),
      ),
    );
  }
}

class _WeightSizePlannerCard extends StatelessWidget {
  const _WeightSizePlannerCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.scale),
        title: const Text('Weight & Size Limits — Planner'),
        subtitle: const Text(
          'Warn if load dims exceed state legal limits along route.',
        ),
        trailing: OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exporting size/weight report…')),
          ),
        ),
      ),
    );
  }
}

class _TrailerCombinationPlannerCard extends StatelessWidget {
  const _TrailerCombinationPlannerCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.merge_type),
        title: const Text('Trailer Combination Lengths — Planner'),
        subtitle: const Text(
          'Check combo legality (e.g., 53’+28’ Rocky Mountain) by state.',
        ),
        trailing: OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exporting combination lengths…')),
          ),
        ),
      ),
    );
  }
}

class _MotorCarrierProgramsCard extends StatelessWidget {
  const _MotorCarrierProgramsCard();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Motor Carrier Programs (IRP, IFTA, UCRA, CSA, NAFTA)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Operating authority, IRP plates, IFTA basics, UCRA registration, CSA 2010 safety, NAFTA notes.',
            ),
          ],
        ),
      ),
    );
  }
}

class _CrossBorderComplianceCard extends StatelessWidget {
  const _CrossBorderComplianceCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: const Text('Cross-Border Dispatch Compliance'),
        subtitle: const Text(
          'Verify loads are compliant for Mexico/Canada; docs & permits.',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _CrossBorderRegulationsCard extends StatelessWidget {
  const _CrossBorderRegulationsCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.rule_folder_outlined),
        title: const Text('Cross-Border Regulations (Broker)'),
        subtitle: const Text(
          'What docs carriers must provide for MX/CA shipments.',
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Ask RoadDogg'),
          onPressed: () => GoRouter.of(context).push('/roaddogg'),
        ),
      ),
    );
  }
}

class _WebRoutePlanning extends StatefulWidget {
  const _WebRoutePlanning();
  @override
  State<_WebRoutePlanning> createState() => _WebRoutePlanningState();
}

class _WebRoutePlanningState extends State<_WebRoutePlanning> {
  // Reuse NJ content when NJ is selected
  final _states = const [
    'Multi-state corridor',
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  ];
  String _sel = 'Multi-state corridor';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Choose:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sel,
                items: _states
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _sel = v ?? _sel),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Planned Routes (CSV)'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Upload dialog coming soon (CSV/dispatch).',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export Compliance PDF'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting compliance PDF…')),
                  );
                },
              ),
            ],
          ),
        ),
        // Role-based module bar for Fleet/Broker on web
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _WebModulesBar(),
        ),
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              width: double.infinity,
              child: _sel == 'NJ'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'New Jersey Truck Routing Guide',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              // Left: lists
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.all(12),
                                  children: [
                                    const Text(
                                      'Legal Truck Routes',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ..._MobileRoutePlanningState._njInterstates
                                        .map(
                                          (e) => ListTile(
                                            leading: const Icon(Icons.check),
                                            title: Text(e),
                                          ),
                                        ),
                                    ..._MobileRoutePlanningState._njUsHighways
                                        .map(
                                          (e) => ListTile(
                                            leading: const Icon(Icons.check),
                                            title: Text(e),
                                          ),
                                        ),
                                    ..._MobileRoutePlanningState._njStateRoutes
                                        .map(
                                          (e) => ListTile(
                                            leading: const Icon(Icons.check),
                                            title: Text(e),
                                          ),
                                        ),
                                    const Divider(),
                                    const Text(
                                      'Prohibited',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ..._MobileRoutePlanningState._njProhibited
                                        .map(
                                          (e) => ListTile(
                                            leading: Icon(
                                              Icons.block,
                                              color: Colors.red.shade300,
                                            ),
                                            title: Text(e),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              // Right: Weigh stations
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.all(12),
                                  children: [
                                    const Text(
                                      'Weigh Stations',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ..._MobileRoutePlanningState
                                        ._njWeighStations
                                        .map(
                                          (e) => ListTile(
                                            leading: const Icon(
                                              Icons.scale_outlined,
                                            ),
                                            title: Text(e),
                                          ),
                                        ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'RoadDogg can alert drivers approaching these. Status subject to change.',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Map: green = legal, red = prohibited (placeholder)',
                        ),
                      ],
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.rule_folder_outlined),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Run compliance checks against planned loads or dispatch routes.',
                ),
              ),
              TextButton(
                child: const Text('Plan route'),
                onPressed: () async {
                  // Minimal smoke test: ask for trailer height and invoke RPC
                  final heightController = TextEditingController(text: '13.6');
                  final h = await showDialog<double>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Trailer height (ft)'),
                      content: TextField(
                        controller: heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'e.g., 13.6'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            final v = double.tryParse(heightController.text.trim());
                            Navigator.of(ctx).pop(v);
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  if (!context.mounted) return;
                  if (h == null) return;
                  final container = ProviderScope.containerOf(context, listen: false);
                  final repo = container.read(truckRestrictionsRepositoryProvider);
                  // Demo polyline: short segment in NH (approx Portsmouth)
                  final poly = <List<double>>[
                    [43.071, -70.762],
                    [43.080, -70.760],
                    [43.090, -70.755],
                  ];
                  try {
                    final hazards = await repo.checkRouteHazardsSimple(polylineLatLngs: poly, trailerHeightFt: h);
                    if (!context.mounted) return;
                    showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Text('Route Hazards (${hazards.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (hazards.isEmpty)
                            const Text('No hazards returned (RPC may not be deployed).')
                          else ...hazards.map((h) => ListTile(
                                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                title: Text('${h['title'] ?? h['description'] ?? 'Hazard'}'),
                                subtitle: Text('${h['category'] ?? ''}'),
                              )),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hazard RPC failed: $e')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              TextButton(
                child: const Text('Ask RoadDogg'),
                onPressed: () => GoRouter.of(context).push('/roaddogg'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _LiveRestrictionsPanel extends ConsumerStatefulWidget {
  final String stateCode;
  const _LiveRestrictionsPanel({required this.stateCode});
  @override
  ConsumerState<_LiveRestrictionsPanel> createState() => _LiveRestrictionsPanelState();
}

class _LiveRestrictionsPanelState extends ConsumerState<_LiveRestrictionsPanel> {
  late final TruckRestrictionsRepository _repo;
  @override
  void initState() {
    super.initState();
    _repo = ref.read(truckRestrictionsRepositoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Live Restrictions (Supabase)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(widget.stateCode, style: TextStyle(color: Colors.blue.shade900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<TruckRestriction>>(
              key: ValueKey(widget.stateCode),
              future: (context as Element).findAncestorWidgetOfExactType<Consumer>() != null
                  ? (context as dynamic).read(truckRestrictionsRepositoryProvider)
                      .fetchOverlaysByStateRpc(widget.stateCode)
                      .catchError((_) => (context as dynamic).read(truckRestrictionsRepositoryProvider).fetchByState(widget.stateCode))
                  : _repo
                      .fetchOverlaysByStateRpc(widget.stateCode)
                      .catchError((_) => _repo.fetchByState(widget.stateCode)), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(children: [CircularProgressIndicator(), SizedBox(width: 12), Text('Loading…')]),
                  );
                }
                if (snapshot.hasError) {
                  return _errorHint(snapshot.error);
                }
                final list = snapshot.data ?? const [];
                if (list.isEmpty) {
                  return const Text('No restrictions found. Seed your dataset or select another state.');
                }
                final lows = list.where((e) => e.category == 'low_clearance').toList();
                final stations = list.where((e) => e.category == 'weigh_station').toList();
                final restricted = list.where((e) => e.category == 'restricted_route').toList();
                return Column(
                  children: [
                    _catTile('Low Clearances', lows, icon: Icons.warning_amber_rounded, color: Colors.red),
                    _catTile('Weigh Stations', stations, icon: Icons.scale_outlined, color: Colors.blue),
                    _catTile('Restricted Routes', restricted, icon: Icons.block, color: Colors.red),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _catTile(String title, List<TruckRestriction> items, {required IconData icon, required Color color}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: items.isNotEmpty,
        leading: Icon(icon, color: color),
        title: Text('$title (${items.length})'),
        children: [
          for (final r in items)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(icon, color: color, size: 18),
              title: Text(r.description),
            ),
        ],
      ),
    );
  }

  Widget _errorHint(Object? error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not load from Supabase', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$error'),
                const SizedBox(height: 8),
                const Text(
                  'Tip: Set SUPABASE_URL and SUPABASE_ANON (legacy SUPABASE_ANON_KEY also supported) via --dart-define or .env and ensure the truck_restrictions table exists. '
                  'Use scripts/seed_truck_restrictions.js to seed data.',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}


Future<void> _confirmRouteOfflineCheck(BuildContext context, WidgetRef ref) async {
  try {
    // Load minimal offline POIs (stub) from asset
    final jsonStr = await rootBundle.loadString('data/state_restrictions.json');
    // Parse for basic validation; current dataset not used further
    jsonDecode(jsonStr);
    // TODO: evaluate current route polyline and intersect with restricted geometries
    // Current dataset lacks geometries; this is a placeholder that reports no conflicts
    final conflicts = <String>[];

    if (conflicts.isNotEmpty) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restricted segment detected (Offline)'),
          content: Text(
            'This route intersects ${conflicts.length} restricted area(s) from offline data. Proceed anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
    } else {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Route check complete'),
          content: const Text('No offline restrictions detected in the current dataset.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Offline check unavailable'),
        content: Text('Could not load offline POIs: $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
