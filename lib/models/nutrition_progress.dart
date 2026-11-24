import 'health_models.dart';

double calorieGoalProgress(int calories, int target) =>
    target <= 0 ? 0 : (calories / target).clamp(0.0, 1.0).toDouble();

double? weightGoalProgress(double? start, double? current, double goal) {
  if (start == null ||
      current == null ||
      !WeightEntry.validPounds(start) ||
      !WeightEntry.validPounds(current) ||
      !WeightEntry.validPounds(goal)) {
    return null;
  }
  if (current == goal) return 1;
  if (start == goal) return 0;
  return ((current - start) / (goal - start)).clamp(0.0, 1.0).toDouble();
}
