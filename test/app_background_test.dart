import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/common/widgets/app_background.dart';

void main() {
  testWidgets('AppBackground shows watermark by default on wide screens', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(800, 600)),
          child: Scaffold(body: AppBackground(child: SizedBox.shrink())),
        ),
      ),
    );
    // Should find the watermark key when enabled and width >= 640
    expect(find.byKey(const Key('app_watermark')), findsOneWidget);
  });

  testWidgets('AppBackground hides watermark when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(800, 600)),
          child: Scaffold(body: AppBackground(watermarkEnabled: false, child: SizedBox.shrink())),
        ),
      ),
    );
    expect(find.byKey(const Key('app_watermark')), findsNothing);
  });

  testWidgets('AppBackground auto-hides watermark on narrow screens', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(500, 800)),
          child: Scaffold(body: AppBackground(child: SizedBox.shrink())),
        ),
      ),
    );
    expect(find.byKey(const Key('app_watermark')), findsNothing);
  });
}
