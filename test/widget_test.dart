import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_app/main.dart';

void main() {
  testWidgets('App loads Home and navigates to Training', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BjjFitnessApp());
    await tester.pumpAndSettle();

    // Home screen is shown first.
    expect(find.text('Hi, Esme!'), findsOneWidget);

    // Tap the Training tab in the bottom bar.
    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle();

    // Training screen content is visible.
    expect(find.text('Log a Training Session'), findsOneWidget);
  });
}
