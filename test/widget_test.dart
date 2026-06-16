import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_app/main.dart';

void main() {
  testWidgets('Home screen shows PULSE title', (WidgetTester tester) async {
    await tester.pumpWidget(const PulseApp());
    expect(find.text('PULSE'), findsOneWidget);
  });
}
