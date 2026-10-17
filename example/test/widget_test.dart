import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash_example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo settles when parked and wakes for keyboard driving', (
    tester,
  ) async {
    await tester.pumpWidget(const DashDemoApp());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.text('D'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    final dashboard = tester.widget<AutoMotoDashboard>(
      find.byType(AutoMotoDashboard),
    );
    expect(dashboard.telemetry.speedKmh, greaterThan(20));
    expect(dashboard.telemetry.odometerKm, greaterThan(12345.6));
    await tester.tap(find.text('P'));
    await tester.pump();
    expect(find.text('车速过高，无法挂 P'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('R'));
    await tester.pump();
    expect(find.text('请先减速再挂 R'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('请先减速再挂 R'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('请先减速再挂 R'), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(
      tester
          .widget<AutoMotoDashboard>(find.byType(AutoMotoDashboard))
          .telemetry
          .speedKmh,
      0,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
