import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/paywall/paywall_card.dart';

void main() {
  testWidgets('PaywallCard shows title, description, and Upgrade button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaywallCard(
            title: 'Pro Feature',
            description: 'Upgrade to unlock.',
          ),
        ),
      ),
    );
    expect(find.text('Pro Feature'), findsOneWidget);
    expect(find.text('Upgrade to unlock.'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });
}
