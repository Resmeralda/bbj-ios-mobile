DateTime _date(Object? v) =>
    DateTime.tryParse(v is String ? v : '') ?? DateTime.now();
DateTime _recoveryDate(Object? value) =>
    DateTime.tryParse(value is String ? value : '') ??
    (throw const FormatException('Recovery record has no valid date.'));
int? _recoveryRating(Object? value) =>
    value is int && value >= 1 && value <= 5 ? value : null;
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
int? _recordedNutrient(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toInt() : null;
String _str(Object? v) => v is String ? v : '';
List<String> _lines(String s) =>
    s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

double _weightValue(Object? value) {
  final pounds = value is num ? value.toDouble() : 0.0;
  return WeightEntry.validPounds(pounds) ? pounds : 0;
}

int _calorieTarget(Object? value) {
  if (value == null) return const NutritionGoals().calories;
  if (value is! num || !value.isFinite || value < 0) return 0;
  final target = value.toInt();
  return value == target ? target : 0;
}

/// users/{uid}/weights/{id}
class WeightEntry {
  static bool validPounds(double pounds) => pounds.isFinite && pounds > 0;

  final String id;
  final DateTime date;
  final double pounds;
  const WeightEntry({
    required this.id,
    required this.date,
    required this.pounds,
  });

  factory WeightEntry.fromMap(String id, Map<String, dynamic> m) {
    final rawDate = m['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    return WeightEntry(
      id: id,
      date: date ?? DateTime.now(),
      pounds: date == null ? 0 : _weightValue(m['pounds']),
    );
  }

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
  final int? _calories, _protein, _carbs, _fat;

  int get calories => _calories ?? 0;
  int get protein => _protein ?? 0;
  int get carbs => _carbs ?? 0;
  int get fat => _fat ?? 0;

  const FoodEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.name,
    required this._calories,
    required this._protein,
    this._carbs = 0,
    this._fat = 0,
  });

  factory FoodEntry.fromMap(String id, Map<String, dynamic> m) => FoodEntry(
    id: id,
    date: _date(m['date']),
    meal: mealTypes.contains(m['meal']) ? m['meal'] as String : 'Snack',
    name: _str(m['name']),
    calories: _recordedNutrient(m['calories']),
    protein: _recordedNutrient(m['protein']),
    carbs: _recordedNutrient(m['carbs']),
    fat: _recordedNutrient(m['fat']),
  );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'meal': meal,
    'name': name,
    'calories': ?_calories,
    'protein': ?_protein,
    'carbs': ?_carbs,
    'fat': ?_fat,
  };
}

/// users/{uid}/recipes/{id}
class Recipe {
  final String id;
  final String name;
  final int? calories, protein, carbs, fat;
  final String ingredients; // one per line
  final String steps; // one per line
  const Recipe({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    this.carbs,
    this.fat,
    required this.ingredients,
    required this.steps,
  });

  List<String> get ingredientList => _lines(ingredients);
  List<String> get stepList => _lines(steps);

  factory Recipe.fromMap(String id, Map<String, dynamic> m) => Recipe(
    id: id,
    name: _str(m['name']),
    calories: _recordedNutrient(m['calories']),
    protein: _recordedNutrient(m['protein']),
    carbs: _recordedNutrient(m['carbs']),
    fat: _recordedNutrient(m['fat']),
    ingredients: _str(m['ingredients']),
    steps: _str(m['steps']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': ?calories,
    'protein': ?protein,
    'carbs': ?carbs,
    'fat': ?fat,
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
    calories: _calorieTarget(m['calories']),
    protein: _int(m['protein'], 150),
    carbs: _int(m['carbs'], 225),
    fat: _int(m['fat'], 65),
    waterOz: _int(m['waterOz'], 80),
    goalWeight: _weightValue(m['goalWeight']),
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

enum MobilityActivity {
  stretching('Stretching'),
  mobilityExercises('Mobility exercises'),
  foamRolling('Foam rolling'),
  yoga('Yoga'),
  other('Other');

  const MobilityActivity(this.label);
  final String label;
}

/// users/{uid}/mobility/{id}
class MobilityEntry {
  const MobilityEntry({
    required this.id,
    required this.date,
    required this.activity,
    required this.minutes,
    this.bodyArea = '',
    this.notes = '',
  });

  final String id;
  final DateTime date;
  final MobilityActivity activity;
  final int minutes;
  final String bodyArea;
  final String notes;

  static bool validMinutes(int? minutes) => minutes != null && minutes > 0;

  factory MobilityEntry.fromMap(String id, Map<String, dynamic> data) {
    final minutes = data['minutes'];
    final activity = MobilityActivity.values
        .where((activity) => activity.name == data['activity'])
        .firstOrNull;
    if (minutes is! int || !validMinutes(minutes) || activity == null) {
      throw const FormatException('Invalid mobility activity or duration.');
    }
    return MobilityEntry(
      id: id,
      date: _recoveryDate(data['date']),
      activity: activity,
      minutes: minutes,
      bodyArea: _str(data['bodyArea']),
      notes: _str(data['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'activity': activity.name,
    'minutes': minutes,
    if (bodyArea.isNotEmpty) 'bodyArea': bodyArea,
    if (notes.isNotEmpty) 'notes': notes,
  };
}

/// users/{uid}/recovery_habits/{localDate}
class RecoveryHabitDay {
  const RecoveryHabitDay({required this.id, required this.windDown});

  final String id;
  final bool windDown;

  static String idFor(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  factory RecoveryHabitDay.fromMap(String id, Map<String, dynamic> data) =>
      RecoveryHabitDay(id: id, windDown: data['windDown'] == true);

  Map<String, dynamic> toMap() => {'windDown': windDown};
}
