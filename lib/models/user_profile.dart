class UserProfile {
  static const belts = ['White', 'Blue', 'Purple', 'Brown', 'Black'];
  static const ageRanges = [
    'Under 18',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55+',
  ];
  static const minWeeklyGoal = 1;
  static const maxWeeklyGoal = 7;
  static const defaultWeeklyGoal = 4;

  static bool validWeeklyGoal(int goal) =>
      goal >= minWeeklyGoal && goal <= maxWeeklyGoal;

  final String name;
  final String belt;
  final String ageRange;
  final int weeklyGoal; // sessions per week
  final String fitnessGoal;
  final String nutritionGoal;

  const UserProfile({
    required this.name,
    required this.belt,
    required this.ageRange,
    required this.weeklyGoal,
    required this.fitnessGoal,
    required this.nutritionGoal,
  });

  UserProfile copyWith({
    String? name,
    String? belt,
    String? ageRange,
    int? weeklyGoal,
    String? fitnessGoal,
    String? nutritionGoal,
  }) => UserProfile(
    name: name ?? this.name,
    belt: belt ?? this.belt,
    ageRange: ageRange ?? this.ageRange,
    weeklyGoal: weeklyGoal ?? this.weeklyGoal,
    fitnessGoal: fitnessGoal ?? this.fitnessGoal,
    nutritionGoal: nutritionGoal ?? this.nutritionGoal,
  );

  // Stored at users/{uid}/settings/profile.
  Map<String, dynamic> toMap() => {
    'name': name,
    'belt': belt,
    'ageRange': ageRange,
    'weeklyGoal': weeklyGoal,
    'fitnessGoal': fitnessGoal,
    'nutritionGoal': nutritionGoal,
  };

  factory UserProfile.fromMap(
    Map<String, dynamic> data, {
    String fallbackName = 'Athlete',
  }) {
    final name = data['name'];
    final belt = data['belt'];
    final age = data['ageRange'];
    final goal = data['weeklyGoal'];
    final fitness = data['fitnessGoal'];
    final nutrition = data['nutritionGoal'];
    return UserProfile(
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : fallbackName,
      belt: belt is String && belts.contains(belt) ? belt : 'White',
      ageRange: age is String && ageRanges.contains(age) ? age : '25-34',
      weeklyGoal: goal is int && validWeeklyGoal(goal)
          ? goal
          : defaultWeeklyGoal,
      fitnessGoal: fitness is String ? fitness : '',
      nutritionGoal: nutrition is String ? nutrition : '',
    );
  }
}
