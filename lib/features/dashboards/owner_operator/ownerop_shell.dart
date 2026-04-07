import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/state/session_provider.dart';
import '../../../common/widgets/app_background.dart';
import '../../../core/ai/roaddogg_logger.dart';
import '../../../core/ai/roaddogg_service.dart';
import 'owner_op_home.dart';


class OwnerOpShell extends ConsumerWidget {
  final String initialInnerRoute;
  const OwnerOpShell({super.key, this.initialInnerRoute = '/ownerop/home'});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(child: _OwnerOpShellScaffold(initialInnerRoute: initialInnerRoute));
  }
}

class _OwnerOpShellScaffold extends StatefulWidget {
  final String initialInnerRoute;
  const _OwnerOpShellScaffold({required this.initialInnerRoute});
  @override
  State<_OwnerOpShellScaffold> createState() => _OwnerOpShellScaffoldState();
}

class _OwnerOpShellScaffoldState extends State<_OwnerOpShellScaffold> {
  final GlobalKey<NavigatorState> _ownerOpNavKey = GlobalKey<NavigatorState>(debugLabel: 'ownerop-nav');
  int _selected = 0;
  bool get _shouldUseDrawer {
    final h = MediaQuery.sizeOf(context).height;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return h < 560 || viewInsets > 0;
  }

  void _push(String route, {bool replace = false}) {
    if (replace) {
      _ownerOpNavKey.currentState?.pushReplacementNamed(route);
    } else {
      _ownerOpNavKey.currentState?.pushNamed(route);
    }
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget screen;
    switch (settings.name) {
      case '/ownerop/loads':
        screen = _OwnerOpSection(title: 'Loads', navKey: _ownerOpNavKey);
        break;
      case '/ownerop/expenses':
        screen = _OwnerOpSection(title: 'Expenses', navKey: _ownerOpNavKey);
        break;
      case '/ownerop/documents':
        screen = _OwnerOpSection(title: 'Documents', navKey: _ownerOpNavKey);
        break;
      case '/ownerop/settings':
        screen = _OwnerOpSection(title: 'Settings', navKey: _ownerOpNavKey);
        break;
      case '/ownerop/home':
      default:
        screen = const _OwnerOpHomePage();
    }
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => PopScope(
        canPop: !(_ownerOpNavKey.currentState?.canPop() ?? false),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            final canPop = _ownerOpNavKey.currentState?.canPop() ?? false;
            if (canPop) {
              _ownerOpNavKey.currentState?.pop();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = widget.initialInnerRoute;
      final nav = _ownerOpNavKey.currentState;
      if (nav != null) {
        nav.pushReplacementNamed(current);
        setState(() {
          _selected = _indexFor(current);
        });
      }
    });
  }

  int _indexFor(String route) {
    switch (route) {
      case '/ownerop/home':
        return 0;
      case '/ownerop/loads':
        return 1;
      case '/ownerop/expenses':
        return 2;
      case '/ownerop/documents':
        return 3;
      case '/ownerop/settings':
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
                  _push('/ownerop/home', replace: true);
                  break;
                case 1:
                  _push('/ownerop/loads');
                  break;
                case 2:
                  _push('/ownerop/expenses');
                  break;
                case 3:
                  _push('/ownerop/documents');
                  break;
                case 4:
                  _push('/ownerop/settings');
                  break;
              }
            },
            labelType: compact ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home_filled), label: Text('Home')),
              NavigationRailDestination(icon: Icon(Icons.assignment_turned_in), label: Text('Loads')),
              NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('Expenses')),
              NavigationRailDestination(icon: Icon(Icons.description), label: Text('Documents')),
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
            key: _ownerOpNavKey,
            initialRoute: '/ownerop/home',
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
            final canPop = _ownerOpNavKey.currentState?.canPop() ?? false;
            if (canPop) _ownerOpNavKey.currentState?.pop();
            return null;
          }),
          UpIntent: CallbackAction<UpIntent>(onInvoke: (intent) {
            _ownerOpNavKey.currentState?.pushReplacementNamed('/ownerop/home');
            return null;
          }),
        },
        child: row,
      ),
    );

    if (_shouldUseDrawer) {
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_roaddogg_ownerop',
          icon: Builder(builder: (context){
            final b = Theme.of(context).brightness;
            return SizedBox(width:24,height:24, child: SvgPicture.asset(b==Brightness.dark ? 'assets/roaddogg/roaddogg_mark_light.svg' : 'assets/roaddogg/roaddogg_mark_dark.svg'));
          }),
          label: const Text('RoadDogg'),
          onPressed: () {
            showDialog(context: context, builder: (ctx) => const _AiDialog(shell: 'ownerop'));
          },
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(child: Text('Owner-Operator')),
              ListTile(leading: const Icon(Icons.home_filled), title: const Text('Home'), onTap: () { Navigator.pop(context); _push('/ownerop/home', replace: true); }),
              ListTile(leading: const Icon(Icons.assignment_turned_in), title: const Text('Loads'), onTap: () { Navigator.pop(context); _push('/ownerop/loads'); }),
              ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Expenses'), onTap: () { Navigator.pop(context); _push('/ownerop/expenses'); }),
              ListTile(leading: const Icon(Icons.description), title: const Text('Documents'), onTap: () { Navigator.pop(context); _push('/ownerop/documents'); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () { Navigator.pop(context); _push('/ownerop/settings'); }),
            ],
          ),
        ),
        body: wrapped,
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_roaddogg_ownerop',
        icon: Builder(builder: (context){
          final b = Theme.of(context).brightness;
          return SizedBox(width:24,height:24, child: SvgPicture.asset(b==Brightness.dark ? 'assets/roaddogg/roaddogg_mark_light.svg' : 'assets/roaddogg/roaddogg_mark_dark.svg'));
        }),
        label: const Text('RoadDogg'),
        onPressed: () {
          showDialog(context: context, builder: (ctx) => const _AiDialog(shell: 'ownerop'));
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
      case 'ownerop': return ['Net CPM for this trip','Fuel stop plan'];
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

class _OwnerOpSection extends StatelessWidget {
  final String title;
  final GlobalKey<NavigatorState> navKey;
  const _OwnerOpSection({required this.title, required this.navKey});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Owner-Op — $title'),
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
                  onPressed: () => navKey.currentState?.pushReplacementNamed('/ownerop/home'),
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

class _OwnerOpHomePage extends StatelessWidget {
  const _OwnerOpHomePage();
  @override
  Widget build(BuildContext context) {
    return const OwnerOpHome(isPremium: true);
  }
}
