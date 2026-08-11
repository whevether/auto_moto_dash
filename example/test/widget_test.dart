import 'package:auto_moto_dash_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo app builds', (tester) async {
    await tester.pumpWidget(const DashDemoApp());
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(DashDemoApp), findsOneWidget);
  });
}