
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_app/data/stores.dart';
import 'package:bjj_app/screens/nutrition_tabs.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NutritionGoalsStore store;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    store = NutritionGoalsStore(firestore: firestore);
    store.bind('test-user');
  });

  tearDown(() {
    store.dispose();
  });

  Future<void> showGoalsTab(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NutritionGoalsTab(store: store),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('Displays default nutrition goals', (tester) async {
    await showGoalsTab(tester);

    expect(find.text('Daily calories'), findsOneWidget);
    expect(find.text('2000 cal'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Edit Goals'), findsOneWidget);
  });

  testWidgets('Opens the Edit Goals form', (tester) async {
    await showGoalsTab(tester);

    await tester.tap(find.text('Edit Goals'));
    await tester.pumpAndSettle();

    expect(find.text('Nutrition goals'), findsOneWidget);
    expect(find.text('Save Goals'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Daily calories'),
        findsOneWidget);
  });

  testWidgets('Saves updated nutrition goals', (tester) async {
    await showGoalsTab(tester);

    await tester.tap(find.text('Edit Goals'));
    await tester.pumpAndSettle();

    final caloriesField = find.widgetWithText(
      TextFormField,
      'Daily calories',
    );

    await tester.enterText(caloriesField, '2300');

    await tester.ensureVisible(find.text('Save Goals'));
    await tester.tap(find.text('Save Goals'));
    await tester.pumpAndSettle();

    expect(find.text('2300 cal'), findsOneWidget);

    final snapshot = await firestore
        .collection('users')
        .doc('test-user')
        .collection('settings')
        .doc('nutrition')
        .get();

    expect(snapshot.data()?['calories'], 2300);
  });
}
