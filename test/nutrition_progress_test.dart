import 'package:bjj_app/models/health_models.dart';
import 'package:bjj_app/models/nutrition_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Calorie progress is bounded and invalid targets produce no fill', () {
    expect(calorieGoalProgress(3000, 2000), 1);
    expect(calorieGoalProgress(750, 1500), .5);
    expect(calorieGoalProgress(-10, 2000), 0);
    expect(calorieGoalProgress(100, 0), 0);
    expect(calorieGoalProgress(100, -100), 0);
  });

  test('Weight progress is directional for loss and gain', () {
    expect(weightGoalProgress(200, 190, 180), .5);
    expect(weightGoalProgress(200, 210, 180), 0);
    expect(weightGoalProgress(200, 179, 180), 1);
    expect(weightGoalProgress(140, 150, 160), .5);
    expect(weightGoalProgress(140, 130, 160), 0);
    expect(weightGoalProgress(140, 161, 160), 1);
  });

  test('An equal baseline can be at goal or off target without division', () {
    expect(weightGoalProgress(180, 180, 180), 1);
    expect(weightGoalProgress(180, 182, 180), 0);
    expect(weightGoalProgress(180, 177, 180), 0);
    expect(weightGoalProgress(null, null, 180), isNull);
    expect(weightGoalProgress(180, null, 180), isNull);
    expect(weightGoalProgress(double.nan, 180, 180), isNull);
    expect(weightGoalProgress(180, double.infinity, 180), isNull);
    expect(weightGoalProgress(180, 180, 0), isNull);
    expect(weightGoalProgress(180, 180, double.infinity), isNull);
  });

  test(
    'Goal decoding preserves defaults and treats invalid targets as unset',
    () {
      expect(NutritionGoals.fromMap({}).calories, 2000);
      expect(NutritionGoals.fromMap({'calories': 2300.0}).calories, 2300);
      for (final invalid in [
        0,
        -10,
        1200.5,
        double.nan,
        double.infinity,
        '2000',
      ]) {
        expect(NutritionGoals.fromMap({'calories': invalid}).calories, 0);
      }
      for (final invalid in [0, -10, double.nan, double.infinity, '180']) {
        expect(NutritionGoals.fromMap({'goalWeight': invalid}).goalWeight, 0);
      }
    },
  );
}
