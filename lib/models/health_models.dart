DateTime _date(Object? v) =>
    DateTime.tryParse(v is String ? v : '') ?? DateTime.now();
DateTime _recoveryDate(Object? value) =>
    DateTime.tryParse(value is String ? value : '') ??
    (throw const FormatException('Recovery record has no valid date.'));
int? _recoveryRating(Object? value) =>
    value is int && value >= 1 && value <= 5 ? value : null;
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
  final String meal;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const FoodEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.name,
    required this.calories,
    required this.protein,
    this.carbs = 0,
    this.fat = 0,
  });

  factory FoodEntry.fromMap(String id, Map<String, dynamic> m) => FoodEntry(
    id: id,
    date: _date(m['date']),
    meal: mealTypes.contains(m['meal']) ? m['meal'] as String : 'Snack',
    name: _str(m['name']),
    calories: _int(m['calories']),
    protein: _int(m['protein']),
    carbs: _int(m['carbs']),
    fat: _int(m['fat']),
  );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'meal': meal,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
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
  static bool validHours(double? hours) =>
      hours != null && hours.isFinite && hours > 0 && hours <= 24;

  final String id;
  final DateTime date;
  final double hours;
  final int? quality; // 1-5, when recorded
  final String notes;
  const SleepEntry({
    required this.id,
    required this.date,
    required this.hours,
    required this.quality,
    required this.notes,
  });

  factory SleepEntry.fromMap(String id, Map<String, dynamic> m) {
    final hours = _num(m['hours']);
    if (!validHours(hours)) {
      throw const FormatException('Sleep record has no valid duration.');
    }
    return SleepEntry(
      id: id,
      date: _recoveryDate(m['date']),
      hours: hours,
      quality: _recoveryRating(m['quality']),
      notes: _str(m['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'hours': hours,
    if (quality != null) 'quality': quality,
    'notes': notes,
  };
}

/// users/{uid}/wellness/{id}
class WellnessEntry {
  static bool validHrv(double? value) =>
      value != null && value.isFinite && value >= 1 && value <= 300;

  final String id;
  final DateTime date;
  final int? energy; // 1-5, when recorded
  final int? soreness; // 1-5, when recorded
  final int? mood; // 1-5, when recorded
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

  factory WellnessEntry.fromMap(String id, Map<String, dynamic> m) {
    final hrv = m['hrv'];
    return WellnessEntry(
      id: id,
      date: _recoveryDate(m['date']),
      energy: _recoveryRating(m['energy']),
      soreness: _recoveryRating(m['soreness']),
      mood: _recoveryRating(m['mood']),
      hrv: hrv is int && validHrv(hrv.toDouble()) ? hrv : null,
      notes: _str(m['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    if (energy != null) 'energy': energy,
    if (soreness != null) 'soreness': soreness,
    if (mood != null) 'mood': mood,
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
        date: _recoveryDate(m['date']),
        title: _str(m['title']),
        body: _str(m['body']),
      );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'title': title,
    'body': body,
  };
}
