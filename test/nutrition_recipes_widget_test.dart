import 'package:bjj_app/data/collection_store.dart';
import 'package:bjj_app/models/health_models.dart';
import 'package:bjj_app/screens/nutrition_tabs.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CollectionStore<Recipe> store;

  setUp(() {
    firestore = FakeFirebaseFirestore();

    store = CollectionStore<Recipe>(
      path: 'recipes',
      firestore: firestore,
      fromMap: Recipe.fromMap,
      toMap: (recipe) => recipe.toMap(),
      idOf: (recipe) => recipe.id,
      compare: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    store.bind('test-user');
  });

  tearDown(() {
    store.dispose();
  });

  Future<void> showRecipesTab(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: NutritionRecipesTab(store: store)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Shows empty state when there are no recipes', (tester) async {
    await showRecipesTab(tester);

    expect(find.text('Add Recipe'), findsOneWidget);
    expect(
      find.text('No recipes yet. Tap Add Recipe to save your first one.'),
      findsOneWidget,
    );
  });

  testWidgets('Opens the Add Recipe form', (tester) async {
    await showRecipesTab(tester);

    await tester.tap(find.text('Add Recipe'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('Displays a saved recipe', (tester) async {
    await firestore
        .collection('users')
        .doc('test-user')
        .collection('recipes')
        .doc('recipe-1')
        .set({
          'name': 'Chicken Rice Bowl',
          'calories': 450,
          'protein': 35,
          'ingredients': 'Chicken\nRice\nBroccoli',
          'steps': 'Cook rice\nCook chicken\nServe',
        });

    await showRecipesTab(tester);
    await tester.pumpAndSettle();

    expect(find.text('Chicken Rice Bowl'), findsOneWidget);
    expect(find.text('450 cal  •  35 g protein'), findsOneWidget);
    expect(find.text('3 ingredients'), findsOneWidget);
  });

  testWidgets('Opens recipe details', (tester) async {
    await firestore
        .collection('users')
        .doc('test-user')
        .collection('recipes')
        .doc('recipe-1')
        .set({
          'name': 'Chicken Rice Bowl',
          'calories': 450,
          'protein': 35,
          'ingredients': 'Chicken\nRice\nBroccoli',
          'steps': 'Cook rice\nCook chicken\nServe',
        });

    await showRecipesTab(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chicken Rice Bowl'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chicken'), findsWidgets);
    expect(find.textContaining('Cook rice'), findsWidgets);
  });

  testWidgets('Adds a recipe and saves it to Firestore', (tester) async {
    await showRecipesTab(tester);

    // Open the Add Recipe form.
    await tester.tap(find.text('Add Recipe'));
    await tester.pumpAndSettle();

    // Fill out the recipe fields.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recipe name'),
      'Protein Pancakes',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories (optional)'),
      '350',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Protein in g (optional)'),
      '25',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ingredients'),
      'Eggs\nOats\nMilk',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Steps'),
      'Mix ingredients\nCook pancakes',
    );

    // Save the recipe.
    await tester.ensureVisible(find.text('Save Recipe'));
    await tester.tap(find.text('Save Recipe'));
    await tester.pumpAndSettle();

    // Verify the recipe appears in the UI.
    expect(find.text('Protein Pancakes'), findsOneWidget);

    // Verify the recipe was saved to Firestore.
    final snapshot = await firestore
        .collection('users')
        .doc('test-user')
        .collection('recipes')
        .get();

    expect(snapshot.docs.length, 1);
    expect(snapshot.docs.first.data()['name'], 'Protein Pancakes');
    expect(snapshot.docs.first.data()['calories'], 350);
    expect(snapshot.docs.first.data()['protein'], 25);
  });

  testWidgets('Edits an existing recipe and updates Firestore', (tester) async {
    // Create a recipe in fake Firestore.
    final recipeRef = firestore
        .collection('users')
        .doc('test-user')
        .collection('recipes')
        .doc('recipe-1');

    await recipeRef.set({
      'name': 'Chicken Rice Bowl',
      'calories': 450,
      'protein': 35,
      'ingredients': 'Chicken\nRice',
      'steps': 'Cook chicken\nCook rice',
    });

    await showRecipesTab(tester);
    await tester.pumpAndSettle();

    // Open the recipe details.
    await tester.tap(find.text('Chicken Rice Bowl'));
    await tester.pumpAndSettle();

    // Open the Edit Recipe form.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Update the recipe name and calories.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recipe name'),
      'Updated Chicken Bowl',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories (optional)'),
      '500',
    );

    // Save the changes.
    await tester.ensureVisible(find.text('Save Recipe'));
    await tester.tap(find.text('Save Recipe'));
    await tester.pumpAndSettle();

    // Verify Firestore contains the updated recipe.
    final updated = await recipeRef.get();

    expect(updated.exists, isTrue);
    expect(updated.data()?['name'], 'Updated Chicken Bowl');
    expect(updated.data()?['calories'], 500);
    expect(updated.data()?['protein'], 35);
  });

  testWidgets('Deletes a recipe from Firestore', (tester) async {
    // Create a recipe in fake Firestore.
    final recipeRef = firestore
        .collection('users')
        .doc('test-user')
        .collection('recipes')
        .doc('recipe-1');

    await recipeRef.set({
      'name': 'Chicken Rice Bowl',
      'calories': 450,
      'protein': 35,
      'ingredients': 'Chicken\nRice',
      'steps': 'Cook chicken\nCook rice',
    });

    await showRecipesTab(tester);
    await tester.pumpAndSettle();

    // Open the recipe details.
    await tester.tap(find.text('Chicken Rice Bowl'));
    await tester.pumpAndSettle();

    // Tap Delete.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirm deletion.
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    // Verify the document was deleted from Firestore.
    final deleted = await recipeRef.get();
    expect(deleted.exists, isFalse);
  });
}
