import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/health_models.dart';
import 'collection_store.dart';

int _newestFirst(DateTime a, DateTime b) => b.compareTo(a);

final weightStore = CollectionStore<WeightEntry>(
  path: 'weights',
  fromMap: WeightEntry.fromMap,
  toMap: (e) => e.toMap(),
  idOf: (e) => e.id,
  compare: (a, b) => _newestFirst(a.date, b.date),
);

final foodStore = CollectionStore<FoodEntry>(
  path: 'food_log',
  fromMap: FoodEntry.fromMap,
  toMap: (e) => e.toMap(),
  idOf: (e) => e.id,
  compare: (a, b) => _newestFirst(a.date, b.date),
);

final recipeStore = CollectionStore<Recipe>(
  path: 'recipes',
  fromMap: Recipe.fromMap,
  toMap: (e) => e.toMap(),
  idOf: (e) => e.id,
  compare: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
);

final sleepStore = CollectionStore<SleepEntry>(
  path: 'sleep',
  fromMap: SleepEntry.fromMap,
  toMap: (e) => e.toMap(),
  idOf: (e) => e.id,
  compare: (a, b) => _newestFirst(a.date, b.date),
);

final wellnessStore = CollectionStore<WellnessEntry>(
  path: 'wellness',
  fromMap: WellnessEntry.fromMap,
  toMap: (e) => e.toMap(),
  idOf: (e) => e.id,
  compare: (a, b) => _newestFirst(a.date, b.date),
);

final noteStore = CollectionStore<RecoveryNote>(
  path: 'recovery_notes',
  fromMap: RecoveryNote.fromMap,
  toMap: (e) => e.toMap(),
  idOf: (e) => e.id,
  compare: (a, b) => _newestFirst(a.date, b.date),
);

/// Nutrition goals: one document at users/{uid}/settings/nutrition.
class NutritionGoalsStore extends ChangeNotifier {
  NutritionGoals goals = const NutritionGoals();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;

  DocumentReference<Map<String, dynamic>>? get _doc => _uid == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('nutrition');

  void bind(String? uid) {
    if (uid == _uid) return;
    _sub?.cancel();
    _sub = null;
    _uid = uid;
    goals = const NutritionGoals();
    notifyListeners();
    if (uid == null) return;

    _sub = _doc!.snapshots().listen((snap) {
      final data = snap.data();
      goals = data == null
          ? const NutritionGoals()
          : NutritionGoals.fromMap(data);
      notifyListeners();
    }, onError: (Object e) => debugPrint('goals sync failed: $e'));
  }

  void save(NutritionGoals g) {
    goals = g;
    notifyListeners();
    _doc?.set(g.toMap()).catchError((Object e) {
      debugPrint('goals write failed: $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final goalsStore = NutritionGoalsStore();

/// Connects every nutrition/recovery store to the signed-in user.
void bindUserData(String? uid) {
  weightStore.bind(uid);
  foodStore.bind(uid);
  recipeStore.bind(uid);
  sleepStore.bind(uid);
  wellnessStore.bind(uid);
  noteStore.bind(uid);
  goalsStore.bind(uid);
}
