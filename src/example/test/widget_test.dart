import 'package:flutter_test/flutter_test.dart';

import 'package:boat_example/main.dart';

void main() {
  testWidgets('App renders harness', (WidgetTester tester) async {
    await tester.pumpWidget(const BoatExampleApp());
    expect(find.text('Boat Engine Harness'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
