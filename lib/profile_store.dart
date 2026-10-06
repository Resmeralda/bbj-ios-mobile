import 'package:flutter/foundation.dart';

import 'models/user_profile.dart';

class ProfileStore extends ChangeNotifier {
  UserProfile profile = const UserProfile(
    name: 'Esme',
    belt: 'White',
    ageRange: '25-34',
    weeklyGoal: 4,
    fitnessGoal: 'Train consistently and improve my guard',
    nutritionGoal: 'Eat enough protein to support training',
  );

  void update(UserProfile p) {
    profile = p;
    notifyListeners();
  }
}

final profileStore = ProfileStore();
