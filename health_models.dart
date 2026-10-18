DateTime _date(Object? v) =>
    DateTime.tryParse(v is String ? v : '') ?? DateTime.now();
double _num(Object? v, [double d = 0]) => (v as num?)?.toDouble() ?? d;
int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
String _str(Object? v) => v is String ? v : '';
List<String> _lines(String s) =>
    s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// users/{uid}/weights/{id}
class WeightEntry {
  final String id;
  final DateTime date;
  final double pounds;
  const WeightEntry({
    required this.id,
    required this.date,
    required this.pounds,
  });

  factory WeightEntry.fromMap(String id, Map<String, dynamic> m) =>
      WeightEntry(id: id, date: _date(m['date']), pounds: _num(m['pounds']));

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'pounds': pounds,
  };
}

const mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

/// users/{uid}/food_log/{id}
class FoodEntry {
  final String id;
  final DateTime date;
  final String meal; // one of [mealTypes]
  final String name;
  final int calories;
  final int protein;
  const FoodEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.name,
    required this.calories,
    required this.protein,
  });

  factory FoodEntry.fromMap(String id, Map<String, dynamic> m) => FoodEntry(
    id: id,
    date: _date(m['date']),
    meal: mealTypes.contains(m['meal']) ? m['meal'] as String : 'Snack',
    name: _str(m['name']),
    calories: _int(m['calories']),
    protein: _int(m['protein']),
  );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'meal': meal,
    'name': name,
    'calories': calories,
    'protein': protein,
  };
}

/// users/{uid}/recipes/{id}
class Recipe {
  final String id;
  final String name;
  final int calories;
  final int protein;
  final String ingredients; // one per line
  final String steps; // one per line
  const Recipe({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.ingredients,
    required this.steps,
  });

  List<String> get ingredientList => _lines(ingredients);
  List<String> get stepList => _lines(steps);

  factory Recipe.fromMap(String id, Map<String, dynamic> m) => Recipe(
    id: id,
    name: _str(m['name']),
    calories: _int(m['calories']),
    protein: _int(m['protein']),
    ingredients: _str(m['ingredients']),
    steps: _str(m['steps']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
    'protein': protein,
    'ingredients': ingredients,
    'steps': steps,
  };
}

/// users/{uid}/settings/nutrition (single document)
class NutritionGoals {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int waterOz;
  final double goalWeight; // 0 = not set
  const NutritionGoals({
    this.calories = 2000,
    this.protein = 150,
    this.carbs = 225,
    this.fat = 65,
    this.waterOz = 80,
    this.goalWeight = 0,
  });

  factory NutritionGoals.fromMap(Map<String, dynamic> m) => NutritionGoals(
    calories: _int(m['calories'], 2000),
    protein: _int(m['protein'], 150),
    carbs: _int(m['carbs'], 225),
    fat: _int(m['fat'], 65),
    waterOz: _int(m['waterOz'], 80),
    goalWeight: _num(m['goalWeight']),
  );

  Map<String, dynamic> toMap() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'waterOz': waterOz,
    'goalWeight': goalWeight,
  };
}

/// users/{uid}/sleep/{id}
class SleepEntry {
  final String id;
  final DateTime date;
  final double hours;
  final int quality; // 1-5
  final String notes;
  const SleepEntry({
    required this.id,
    required this.date,
    required this.hours,
    required this.quality,
    required this.notes,
  });

  factory SleepEntry.fromMap(String id, Map<String, dynamic> m) => SleepEntry(
    id: id,
    date: _date(m['date']),
    hours: _num(m['hours']),
    quality: _int(m['quality'], 3),
    notes: _str(m['notes']),
  );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'hours': hours,
    'quality': quality,
    'notes': notes,
  };
}

/// users/{uid}/wellness/{id}
class WellnessEntry {
  final String id;
  final DateTime date;
  final int energy; // 1-5
  final int soreness; // 1-5
  final int mood; // 1-5
  final int? hrv; // optional, in ms
  final String notes;
  const WellnessEntry({
    required this.id,
    required this.date,
    required this.energy,
    required this.soreness,
    required this.mood,
    required this.notes,
    this.hrv,
  });

  factory WellnessEntry.fromMap(String id, Map<String, dynamic> m) =>
      WellnessEntry(
        id: id,
        date: _date(m['date']),
        energy: _int(m['energy'], 3),
        soreness: _int(m['soreness'], 3),
        mood: _int(m['mood'], 3),
        hrv: (m['hrv'] as num?)?.toInt(),
        notes: _str(m['notes']),
      );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'energy': energy,
    'soreness': soreness,
    'mood': mood,
    if (hrv != null) 'hrv': hrv,
    'notes': notes,
  };
}

/// users/{uid}/recovery_notes/{id}
class RecoveryNote {
  final String id;
  final DateTime date;
  final String title;
  final String body;
  const RecoveryNote({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
  });

  factory RecoveryNote.fromMap(String id, Map<String, dynamic> m) =>
      RecoveryNote(
        id: id,
        date: _date(m['date']),
        title: _str(m['title']),
        body: _str(m['body']),
      );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'title': title,
    'body': body,
  };
}
