import 'package:flutter/foundation.dart';

import 'models/user_profile.dart';

const _defaultProfile = UserProfile(
  name: 'Esme',
  belt: 'White',
  ageRange: '25-34',
  weeklyGoal: 4,
  fitnessGoal: 'Train consistently and improve my guard',
  nutritionGoal: 'Eat enough protein to support training',
);

class ProfileStore extends ChangeNotifier {
  UserProfile profile = _defaultProfile;

  void update(UserProfile p) {
    profile = p;
    notifyListeners();
  }

  /// Called on login/logout so profiles don't carry over between accounts.
  void reset({String? name}) {
    final n = (name ?? '').trim();
    profile = _defaultProfile.copyWith(name: n.isEmpty ? 'Athlete' : n);
    notifyListeners();
  }
}

final profileStore = ProfileStore();
