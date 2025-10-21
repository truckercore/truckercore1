import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/state/session_provider.dart';
import '../../../core/dashboards/dashboard_window_manager.dart';
import '../models/dashboard_metadata.dart';
import '../models/dashboard_template.dart';
import '../providers/dashboard_preferences_provider.dart';
import '../providers/dashboard_user_state.dart';
import '../services/dashboard_analytics.dart';

class DashboardMarketplaceScreen extends ConsumerStatefulWidget {
  const DashboardMarketplaceScreen({super.key});

  @override
  ConsumerState<DashboardMarketplaceScreen> createState() => _DashboardMarketplaceScreenState();
}

class _DashboardMarketplaceScreenState extends ConsumerState<DashboardMarketplaceScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredDashboards = _filterDashboards();
    final categories = _getCategories();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: () {
              if (!mounted) return;
              context.push('/dashboards/analytics');
            },
            tooltip: 'Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _chooseTemplate,
            tooltip: 'Templates',
          ),
          IconButton(
            icon: const Icon(Icons.all_inbox),
            onPressed: _openAllDashboardsQA,
            tooltip: 'Open All (QA)',
          ),
          IconButton(
            icon: const Icon(Icons.window),
            onPressed: _showOpenDashboards,
            tooltip: 'Open Dashboards',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search dashboards...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                  ),
                  onChanged: (value) {
                                      setState(() => _searchQuery = value.toLowerCase());
                                      // Track filter usage (debounce omitted for simplicity)
                                      DashboardAnalytics.trackFilterUsed(query: value.toLowerCase(), category: _selectedCategory);
                                    },
                ),
                const SizedBox(height: 16),
                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) {
                                                    setState(() => _selectedCategory = category);
                                                    DashboardAnalytics.trackFilterUsed(query: _searchQuery, category: category);
                                                  },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Dashboard Grid
          Expanded(
            child: filteredDashboards.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filteredDashboards.length,
                    itemBuilder: (context, index) {
                      return _DashboardCard(dashboard: filteredDashboards[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<DashboardMetadata> _filterDashboards() {
    // Start with all dashboards
    var filtered = List<DashboardMetadata>.from(availableDashboards);

    // Role-based filtering: only show dashboards allowed for current role (if specified)
    try {
      final session = ref.read(sessionProvider);
      final role = session.role;
      filtered = filtered.where((d) => d.allowedRoles.isEmpty || d.allowedRoles.contains(role)).toList();
    } catch (_) {}

    // Category filtering
    if (_selectedCategory != 'All') {
      if (_selectedCategory == 'Favorites') {
        final favs = ref.read(dashboardUserStateProvider).favorites;
        filtered = filtered.where((d) => favs.contains(d.id)).toList();
      } else if (_selectedCategory == 'Recent') {
        final recents = ref.read(dashboardUserStateProvider).recents;
        final map = {for (final d in filtered) d.id: d};
        filtered = recents.map((id) => map[id]).whereType<DashboardMetadata>().toList();
      } else {
        // Custom collection?
        final collections = ref.read(dashboardUserStateProvider).collections;
        if (collections.containsKey(_selectedCategory)) {
          final ids = collections[_selectedCategory] ?? const <String>[];
          final map = {for (final d in filtered) d.id: d};
          filtered = ids.map((id) => map[id]).whereType<DashboardMetadata>().toList();
        } else {
          // Standard category
          filtered = filtered.where((d) => d.category == _selectedCategory).toList();
        }
      }
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((d) {
        return d.name.toLowerCase().contains(_searchQuery) ||
            d.description.toLowerCase().contains(_searchQuery) ||
            d.features.any((f) => f.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    return filtered;
  }

  List<String> _getCategories() {
    final categories = <String>{'All', 'Favorites', 'Recent'};
    // Add user collections
    final userState = ref.read(dashboardUserStateProvider);
    categories.addAll(userState.collections.keys);
    for (final d in availableDashboards) {
      categories.add(d.category);
    }
    return categories.toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('No dashboards found', style: TextStyle(fontSize: 18, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('Try adjusting your search or filters', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showOpenDashboards() {
    showDialog(context: context, builder: (_) => const _OpenDashboardsDialog());
  }

  Future<void> _chooseTemplate() async {
    final choice = await showDialog<DashboardTemplate>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Apply Template'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DashboardTemplate.dispatcher),
            child: const Text('Dispatcher (Fleet Overview + Live Tracking)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DashboardTemplate.manager),
            child: const Text('Manager (All dashboards)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DashboardTemplate.driver),
            child: const Text('Driver (Driver Performance)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DashboardTemplate.maintenance),
            child: const Text('Maintenance (Fuel & Maintenance)'),
          ),
        ],
      ),
    );
    if (choice != null) {
      await TemplateManager.applyTemplate(choice);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template applied')),
      );
    }
  }

  Future<void> _openAllDashboardsQA() async {
    // Ask for mock vehicle count
    int count = 50;
    if (mounted) {
      final chosen = await showDialog<int>(
        context: context,
        builder: (ctx) {
          return SimpleDialog(
            title: const Text('Mock Fleet Size'),
            children: [
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 10), child: const Text('10 vehicles')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 50), child: const Text('50 vehicles')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 100), child: const Text('100 vehicles')),
            ],
          );
        },
      );
      if (chosen != null) count = chosen;
    }

    // Force auto-refresh=5s for all dashboards
    try {
      for (final d in availableDashboards) {
        final prefs = ref.read(dashboardPreferencesProvider(d.id).notifier);
        prefs.setAutoRefresh(true);
        prefs.setRefreshInterval(5);
      }
    } catch (_) {}

    final manager = DashboardWindowManager();
    final params = {'mockVehicleCount': count};
    for (final d in availableDashboards) {
      await manager.openDashboard(d.id, params: params);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opened all dashboards (auto-refresh 5s, mock=$count)')),
    );
  }
}

class _DashboardCard extends ConsumerWidget {
  final DashboardMetadata dashboard;
  const _DashboardCard({required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowManager = DashboardWindowManager();
    final isOpen = windowManager.isDashboardOpen(dashboard.id);
    final session = ref.read(sessionProvider);
    final allowed = dashboard.allowedRoles.isEmpty || dashboard.allowedRoles.contains(session.role);
    final userState = ref.watch(dashboardUserStateProvider);
    final isFavorite = userState.favorites.contains(dashboard.id);

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDashboard(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dashboard.color, dashboard.color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(dashboard.icon, size: 64, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  if (dashboard.isPremium)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.black),
                            SizedBox(width: 4),
                            Text('PRO', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  if (isOpen)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('OPEN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  // Favorite toggle
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.redAccent : Colors.white),
                        onPressed: () async {
                          final wasFavorite = isFavorite;
                          await ref.read(dashboardUserStateProvider.notifier).toggleFavorite(dashboard.id);
                          // Track favorite toggle
                          DashboardAnalytics.trackFavorite(dashboard.id, enabled: !wasFavorite);
                        },
                        tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
                      ),
                    ),
                  ),
                  // Preview
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _preview(context, ref),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.remove_red_eye, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Preview', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Lock overlay when not allowed by role
                  if (!allowed)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: Icon(Icons.lock, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dashboard.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dashboard.category,
                      style: TextStyle(fontSize: 12, color: dashboard.color, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dashboard.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: dashboard.features.take(2).map((feature) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(feature, style: const TextStyle(fontSize: 11)),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: allowed ? () => _openDashboard(context, ref) : null,
                        icon: Icon(isOpen ? Icons.visibility : Icons.open_in_new),
                        label: Text(allowed ? (isOpen ? 'View' : 'Open') : 'Restricted'),
                        style: ElevatedButton.styleFrom(backgroundColor: dashboard.color, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDashboard(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final allowed = dashboard.allowedRoles.isEmpty || dashboard.allowedRoles.contains(session.role);
    if (!allowed) {
      messenger?.showSnackBar(const SnackBar(content: Text('You do not have permission to open this dashboard')));
      return;
    }
    final windowManager = DashboardWindowManager();
    final dashName = dashboard.name;
    final dashId = dashboard.id;
    windowManager.openDashboard(dashId).then((_) async {
      // Track recent
      await ref.read(dashboardUserStateProvider.notifier).addRecent(dashId);
      messenger?.showSnackBar(SnackBar(content: Text('$dashName opened'), duration: const Duration(seconds: 2)));
    }).catchError((error) {
      messenger?.showSnackBar(SnackBar(content: Text('Failed to open dashboard: $error'), backgroundColor: Colors.red));
    });
  }

  void _preview(BuildContext context, WidgetRef ref) {
    // Track preview view
    DashboardAnalytics.trackPreview(dashboard.id);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(backgroundColor: dashboard.color, child: Icon(dashboard.icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Text(dashboard.name)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dashboard.description),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dashboard.features.map((f) => Chip(label: Text(f))).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                DashboardAnalytics.trackPreviewOpen(dashboard.id);
                _openDashboard(context, ref);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open'),
            ),
          ],
        );
      },
    );
  }
}

class _OpenDashboardsDialog extends ConsumerWidget {
  const _OpenDashboardsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowManager = DashboardWindowManager();
    final openDashboards = availableDashboards.where((d) => windowManager.isDashboardOpen(d.id)).toList();

    return AlertDialog(
      title: const Text('Open Dashboards'),
      content: SizedBox(
        width: 400,
        child: openDashboards.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No dashboards are currently open', textAlign: TextAlign.center),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: openDashboards.length,
                itemBuilder: (context, index) {
                  final dashboard = openDashboards[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: dashboard.color,
                      child: Icon(dashboard.icon, color: Colors.white, size: 20),
                    ),
                    title: Text(dashboard.name),
                    subtitle: Text(dashboard.category),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        windowManager.closeDashboard(dashboard.id);
                        Navigator.of(context).pop();
                      },
                      tooltip: 'Close',
                    ),
                    onTap: () {
                      windowManager.openDashboard(dashboard.id);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
      ),
      actions: [
        if (openDashboards.isNotEmpty)
          TextButton(
            onPressed: () {
              windowManager.closeAllDashboards();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Close All'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
