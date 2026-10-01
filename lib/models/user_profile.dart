class UserProfile {
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

  // Ready for Cloud Firestore: users/{uid}
  Map<String, dynamic> toMap() => {
    'name': name,
    'belt': belt,
    'ageRange': ageRange,
    'weeklyGoal': weeklyGoal,
    'fitnessGoal': fitnessGoal,
    'nutritionGoal': nutritionGoal,
  };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    name: m['name'] ?? '',
    belt: m['belt'] ?? 'White',
    ageRange: m['ageRange'] ?? '25-34',
    weeklyGoal: m['weeklyGoal'] ?? 4,
    fitnessGoal: m['fitnessGoal'] ?? '',
    nutritionGoal: m['nutritionGoal'] ?? '',
  );
}
