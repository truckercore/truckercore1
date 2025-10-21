import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke: renders a simple widget and finds text', (tester) async {
    const text = 'Hello, TruckerCore!';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text(text))),
      ),
    );

    expect(find.text(text), findsOneWidget);
  });
}
