import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/widgets/app_background.dart';
import 'widgets/route_board.dart';

class DispatchShell extends ConsumerWidget {
  const DispatchShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(44),
          child: Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8, right: 16),
            child: Wrap(spacing: 8, children: [
              Chip(label: Text('Today')),
              Chip(label: Text('Now')),
              Chip(label: Text('All equipment')),
            ]),
          ),
        ),
      ),
      body: const AppBackground(child: Padding(
        padding: EdgeInsets.all(12),
        child: RouteBoard(),
      )),
    );
  }
}
