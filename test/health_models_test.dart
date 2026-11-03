
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_app/models/health_models.dart';

void main() {
  group('WeightEntry', () {
    test('Converts weight entry to and from Firestore data', () {
      final date = DateTime(2026, 11, 3);
      final entry = WeightEntry(
        id: 'weight-1',
        date: date,
        pounds: 185.5,
      );

      final restored = WeightEntry.fromMap(entry.id, entry.toMap());

      expect(restored.id, 'weight-1');
      expect(restored.date, date);
      expect(restored.pounds, 185.5);
    });

    test('Handles missing weight values', () {
      final entry = WeightEntry.fromMap('weight-2', {});

      expect(entry.pounds, 0);
      expect(entry.date, isA<DateTime>());
    });
  });

  group('FoodEntry', () {
    test('Converts food entry to and from Firestore data', () {
      final entry = FoodEntry(
        id: 'food-1',
        date: DateTime(2026, 11, 3),
        meal: 'Breakfast',
        name: 'Avocado Toast',
        calories: 300,
        protein: 15,
      );

      final restored = FoodEntry.fromMap(entry.id, entry.toMap());

      expect(restored.id, 'food-1');
      expect(restored.meal, 'Breakfast');
      expect(restored.name, 'Avocado Toast');
      expect(restored.calories, 300);
      expect(restored.protein, 15);
      expect(restored.date, entry.date);
    });

    test('Uses Snack when meal type is invalid', () {
      final entry = FoodEntry.fromMap('food-2', {
        'meal': 'Invalid Meal',
        'name': 'Banana',
      });

      expect(entry.meal, 'Snack');
      expect(entry.calories, 0);
      expect(entry.protein, 0);
    });
  });

  group('Recipe', () {
    test('Converts recipe to and from Firestore data', () {
      const recipe = Recipe(
        id: 'recipe-1',
        name: 'Protein Smoothie',
        calories: 350,
        protein: 30,
        ingredients: 'Milk\nBanana\nProtein Powder',
        steps: 'Add ingredients\nBlend\nServe',
      );

      final restored = Recipe.fromMap(recipe.id, recipe.toMap());

      expect(restored.id, 'recipe-1');
      expect(restored.name, 'Protein Smoothie');
      expect(restored.calories, 350);
      expect(restored.protein, 30);
      expect(restored.ingredientList, [
        'Milk',
        'Banana',
        'Protein Powder',
      ]);
      expect(restored.stepList, [
        'Add ingredients',
        'Blend',
        'Serve',
      ]);
    });

    test('Ignores empty lines in ingredients and steps', () {
      const recipe = Recipe(
        id: 'recipe-2',
        name: 'Eggs',
        calories: 150,
        protein: 12,
        ingredients: 'Eggs\n\n Salt \n',
        steps: 'Cook\n\nServe',
      );

      expect(recipe.ingredientList, ['Eggs', 'Salt']);
      expect(recipe.stepList, ['Cook', 'Serve']);
    });
  });

  group('NutritionGoals', () {
    test('Uses default nutrition goals', () {
      const goals = NutritionGoals();

      expect(goals.calories, 2000);
      expect(goals.protein, 150);
      expect(goals.carbs, 225);
      expect(goals.fat, 65);
      expect(goals.waterOz, 80);
      expect(goals.goalWeight, 0);
    });

    test('Converts nutrition goals to and from Firestore data', () {
      const goals = NutritionGoals(
        calories: 2200,
        protein: 175,
        carbs: 250,
        fat: 70,
        waterOz: 100,
        goalWeight: 175,
      );

      final restored = NutritionGoals.fromMap(goals.toMap());

      expect(restored.calories, 2200);
      expect(restored.protein, 175);
      expect(restored.carbs, 250);
      expect(restored.fat, 70);
      expect(restored.waterOz, 100);
      expect(restored.goalWeight, 175);
    });

    test('Uses defaults when goal fields are missing', () {
      final goals = NutritionGoals.fromMap({});

      expect(goals.calories, 2000);
      expect(goals.protein, 150);
      expect(goals.carbs, 225);
      expect(goals.fat, 65);
      expect(goals.waterOz, 80);
      expect(goals.goalWeight, 0);
    });
  });
}
