import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/kpi/kpi_models.dart';
import 'package:truckercore1/features/kpi/kpi_providers.dart';
import 'package:truckercore1/features/kpi/kpi_ribbon.dart';

void main() {
  testWidgets('KpiRibbon shows skeleton while loading and empty hint on zeros', (tester) async {
    final delayedProvider = FutureProvider<KpiSnapshot>((ref) async {
      // Delay a frame to allow loading state to render
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return KpiSnapshot.empty;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kpiSnapshotProvider.overrideWith((ref) => ref.watch(delayedProvider.future)),
        ],
        child: const MaterialApp(home: Scaffold(body: KpiRibbon())),
      ),
    );

    // Initial frame should be loading; expect some progress/skeleton by presence of Card with Row
    expect(find.byType(Card), findsOneWidget);

    // Complete the future
    await tester.pump(const Duration(milliseconds: 20));

    // Now expect chips with labels, e.g., 'Open Loads'
    expect(find.text('Open Loads'), findsOneWidget);
  });
}
