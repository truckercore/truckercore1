import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/state/session_provider.dart';
import '../../../common/widgets/app_background.dart';
import '../../../core/ai/roaddogg_logger.dart';
import '../../../core/ai/roaddogg_service.dart';
import '../../fleet/dispatch/dispatch_shell.dart';
import 'fleet_home.dart';


class FleetShell extends ConsumerWidget {
  final String initialInnerRoute;
  const FleetShell({super.key, this.initialInnerRoute = '/fleet/dashboard'});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(child: _FleetShellScaffold(initialInnerRoute: initialInnerRoute));
  }
}

class _FleetShellScaffold extends StatefulWidget {
  final String initialInnerRoute;
  const _FleetShellScaffold({required this.initialInnerRoute});
  @override
  State<_FleetShellScaffold> createState() => _FleetShellScaffoldState();
}

class _FleetShellScaffoldState extends State<_FleetShellScaffold> {
  final GlobalKey<NavigatorState> _fleetNavKey = GlobalKey<NavigatorState>(debugLabel: 'fleet-nav');
  int _selected = 0;
  bool get _shouldUseDrawer {
    final h = MediaQuery.sizeOf(context).height;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return h < 560 || viewInsets > 0;
  }

  void _push(String route, {bool replace = false}) {
    if (replace) {
      _fleetNavKey.currentState?.pushReplacementNamed(route);
    } else {
      _fleetNavKey.currentState?.pushNamed(route);
    }
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget screen;
    switch (settings.name) {
      case '/fleet/dispatch':
        screen = const DispatchShell();
        break;
      case '/fleet/safety':
        screen = _FleetSection(title: 'Safety', navKey: _fleetNavKey);
        break;
      case '/fleet/hos':
        screen = _FleetSection(title: 'HOS', navKey: _fleetNavKey);
        break;
      case '/fleet/analytics':
        screen = _FleetSection(title: 'Analytics', navKey: _fleetNavKey);
        break;
      case '/fleet/settings':
        screen = _FleetSection(title: 'Settings', navKey: _fleetNavKey);
        break;
      case '/fleet/dashboard':
      default:
        // Embed existing FleetHome dashboard content as the Home route
        screen = const _FleetHomePage();
    }
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => PopScope(
        canPop: !(_fleetNavKey.currentState?.canPop() ?? false),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            final canPop = _fleetNavKey.currentState?.canPop() ?? false;
            if (canPop) {
              _fleetNavKey.currentState?.pop();
            }
          }
        },
        child: screen,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Defer to next frame to allow Navigator to mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = widget.initialInnerRoute;
      final nav = _fleetNavKey.currentState;
      if (nav != null) {
        // If not at desired route, navigate
        nav.pushReplacementNamed(current);
        setState(() {
          _selected = _indexFor(current);
        });
      }
    });
  }

  int _indexFor(String route) {
    switch (route) {
      case '/fleet/dashboard':
        return 0;
      case '/fleet/dispatch':
        return 1;
      case '/fleet/safety':
        return 2;
      case '/fleet/analytics':
        return 3;
      case '/fleet/settings':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 700;

    final rail = LayoutBuilder(
      builder: (context, constraints) {
        final railContent = IntrinsicHeight(
          child: NavigationRail(
            selectedIndex: _selected,
            onDestinationSelected: (i) {
              setState(() => _selected = i);
              switch (i) {
                case 0:
                  _push('/fleet/dashboard', replace: true);
                  break;
                case 1:
                  _push('/fleet/dispatch');
                  break;
                case 2:
                  _push('/fleet/safety');
                  break;
                case 3:
                  _push('/fleet/analytics');
                  break;
                case 4:
                  _push('/fleet/settings');
                  break;
              }
            },
            labelType: compact ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home_filled), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.route), label: Text('Dispatch')),
              NavigationRailDestination(icon: Icon(Icons.shield_moon), label: Text('Safety')),
              NavigationRailDestination(icon: Icon(Icons.insights), label: Text('Analytics')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: railContent,
          ),
        );
      },
    );

    final row = Row(
      children: [
        if (!_shouldUseDrawer) rail else const SizedBox.shrink(),
        if (!_shouldUseDrawer) const VerticalDivider(width: 1),
        Expanded(
          child: Navigator(
            key: _fleetNavKey,
            initialRoute: '/fleet/dashboard',
            onGenerateRoute: _onGenerateRoute,
          ),
        ),
      ],
    );

    final Widget wrapped = Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowLeft): const BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowUp): const UpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          BackIntent: CallbackAction<BackIntent>(onInvoke: (intent) {
            final canPop = _fleetNavKey.currentState?.canPop() ?? false;
            if (canPop) _fleetNavKey.currentState?.pop();
            return null;
          }),
          UpIntent: CallbackAction<UpIntent>(onInvoke: (intent) {
            _fleetNavKey.currentState?.pushReplacementNamed('/fleet/dashboard');
            return null;
          }),
        },
        child: row,
      ),
    );

    if (_shouldUseDrawer) {
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_roaddogg_fleet',
          icon: Builder(builder: (context){
            final b = Theme.of(context).brightness;
            return SizedBox(width:24,height:24, child: SvgPicture.asset(b==Brightness.dark ? 'assets/roaddogg/roaddogg_mark_light.svg' : 'assets/roaddogg/roaddogg_mark_dark.svg'));
          }),
          label: const Text('RoadDogg'),
          onPressed: () {
            showDialog(context: context, builder: (ctx) => const _AiDialog(shell: 'fleet'));
          },
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(child: Text('Fleet Manager')),
              ListTile(leading: const Icon(Icons.home_filled), title: const Text('Dashboard'), onTap: () { Navigator.pop(context); _push('/fleet/dashboard', replace: true); }),
              ListTile(leading: const Icon(Icons.route), title: const Text('Dispatch'), onTap: () { Navigator.pop(context); _push('/fleet/dispatch'); }),
              ListTile(leading: const Icon(Icons.shield_moon), title: const Text('Safety'), onTap: () { Navigator.pop(context); _push('/fleet/safety'); }),
              ListTile(leading: const Icon(Icons.insights), title: const Text('Analytics'), onTap: () { Navigator.pop(context); _push('/fleet/analytics'); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () { Navigator.pop(context); _push('/fleet/settings'); }),
            ],
          ),
        ),
        body: wrapped,
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_roaddogg_fleet',
        icon: Builder(builder: (context){
          final b = Theme.of(context).brightness;
          return SizedBox(width:24,height:24, child: SvgPicture.asset(b==Brightness.dark ? 'assets/roaddogg/roaddogg_mark_light.svg' : 'assets/roaddogg/roaddogg_mark_dark.svg'));
        }),
        label: const Text('RoadDogg'),
        onPressed: () {
          showDialog(context: context, builder: (ctx) => const _AiDialog(shell: 'fleet'));
        },
      ),
      body: wrapped,
    );
  }
}

class _AiDialog extends ConsumerStatefulWidget {
  final String shell; const _AiDialog({required this.shell});
  @override
  ConsumerState<_AiDialog> createState() => _AiDialogState();
}
class _AiDialogState extends ConsumerState<_AiDialog> {
  final _input = TextEditingController();
  String _intent = '';
  String _output = '';
  bool _busy = false;
  @override
  void dispose(){ _input.dispose(); super.dispose(); }
  List<String> get _presets {
    switch(widget.shell){
      case 'fleet': return ['Best driver for this load','Safety hotspots this week'];
      default: return ['Ask'];
    }
  }
  Future<void> _run() async {
    if (_busy) return; setState(()=>_busy=true);
    try{
      final svc = ref.read(roaddoggServiceProvider);
      final logger = ref.read(roaddoggLoggerProvider);
      final plan = ref.read(sessionProvider).isPremium ? 'pro' : 'free';
      final ctx = {'shell': widget.shell, 'route': 'current'};
      final ans = await svc.ask(role: widget.shell, planTier: plan, intent: _intent.isEmpty? 'ad-hoc':_intent, context: ctx);
      setState(()=>_output = ans.text);
      await logger.log(action: 'ai_roaddogg', payload: {'intent': _intent, 'plan': plan});
    } finally { if(mounted) setState(()=>_busy=false);} }
  @override
  Widget build(BuildContext context){
    final isFree = !ref.watch(sessionProvider).isPremium;
    return Scaffold(
      appBar: AppBar(title: const Text('RoadDogg')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Wrap(spacing:8, children:[ for(final p in _presets) ChoiceChip(label: Text(p), selected: _intent==p, onSelected: (_){ setState(()=>_intent=p); }) ]),
          const SizedBox(height:8),
          TextField(controller: _input, decoration: const InputDecoration(labelText:'Ask anything', border: OutlineInputBorder())),
          const SizedBox(height:8),
          Row(children:[
            ElevatedButton.icon(onPressed: _busy? null : _run, icon: _busy? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.smart_toy_outlined), label: const Text('Ask')),
            const SizedBox(width:8),
            if(isFree) const Chip(label: Text('Pro required for actions')),
          ]),
          const Divider(),
          Expanded(child: SingleChildScrollView(child: Text(_output.isEmpty? 'No output yet.' : _output)))
        ],
      )),
    );
  }
}

class _FleetSection extends StatelessWidget {
  final String title;
  final GlobalKey<NavigatorState> navKey;
  const _FleetSection({required this.title, required this.navKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fleet — $title'),
        actions: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => navKey.currentState?.maybePop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => navKey.currentState?.pushReplacementNamed('/fleet/dashboard'),
                  child: const Text('Home'),
                ),
                const Text(' › '),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$title (stub page) — content coming soon'),
            ),
          ),
        ),
      ),
    );
  }
}

class BackIntent extends Intent { const BackIntent(); }
class UpIntent extends Intent { const UpIntent(); }

class _FleetHomePage extends StatelessWidget {
  const _FleetHomePage();
  @override
  Widget build(BuildContext context) {
    // Keep existing FleetHome content as Home under nested navigator
    // Since FleetHome is a full Scaffold, we just return it.
    return const FleetHome(isPremium: true); // premium will be handled by outer builder
  }
}
