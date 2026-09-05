import 'package:flutter_test/flutter_test.dart';
import 'package:passenger_app/main.dart';

void main() {
  testWidgets('Passenger app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GigaPassengerApp());
    expect(find.byType(GigaPassengerApp), findsOneWidget);
  });
}
