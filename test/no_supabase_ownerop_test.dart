import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/dashboards/owner_operator/owner_op_home.dart'
    as owner;

void main() {
  testWidgets('no-supabase mode: OwnerOpHome renders without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: owner.OwnerOpHome(isPremium: false)),
      ),
    );
    await tester.pumpAndSettle();
    // Expect to find the page title without crashes
    expect(find.text('Owner-Operator Dashboard'), findsOneWidget);
  });
}
