// part: kpis refresh strip shown in FleetHome header
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/last_updated_badge.dart';
import '../../fleet/kpis/kpis_controller.dart';

class KpisRefreshStrip extends ConsumerStatefulWidget {
  const KpisRefreshStrip({super.key});
  @override
  ConsumerState<KpisRefreshStrip> createState() => KpisRefreshStripState();
}

class KpisRefreshStripState extends ConsumerState<KpisRefreshStrip> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kpisControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(kpisControllerProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: LastUpdatedBadge(
        lastUpdated: st.lastUpdated,
        isRefreshing: st.isRefreshing,
        onRefresh: () => ref.read(kpisControllerProvider.notifier).refresh(),
      ),
    );
  }
}
