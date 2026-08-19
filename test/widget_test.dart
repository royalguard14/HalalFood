import 'package:flutter_test/flutter_test.dart';

import 'package:halalfood/app/app.dart';

void main() {
  testWidgets('HALAL Food app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const HalalFoodApp());

    expect(find.text('HALAL FOOD'), findsOneWidget);
  });
}