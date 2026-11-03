
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_app/data/stores.dart';
import 'package:bjj_app/models/health_models.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NutritionGoalsStore store;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    store = NutritionGoalsStore(firestore: firestore);
    store.bind('test-user');
  });

  tearDown(() {
    store.dispose();
  });

  test('Starts with default nutrition goals', () {
    expect(store.goals.calories, 2000);
    expect(store.goals.protein, 150);
    expect(store.goals.goalWeight, 0);
  });

  test('Saves nutrition goals to Firestore', () async {
    const goals = NutritionGoals(
      calories: 2200,
      protein: 175,
      goalWeight: 175,
    );

    store.save(goals);

    final snapshot = await firestore
        .collection('users')
        .doc('test-user')
        .collection('settings')
        .doc('nutrition')
        .get();

    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['calories'], 2200);
    expect(snapshot.data()?['protein'], 175);
    expect(snapshot.data()?['goalWeight'], 175);
  });

  test('Loads saved nutrition goals from Firestore', () async {
    await firestore
        .collection('users')
        .doc('test-user')
        .collection('settings')
        .doc('nutrition')
        .set({
          'calories': 2500,
          'protein': 180,
          'goalWeight': 170,
        });

    await pumpEventQueue();

    expect(store.goals.calories, 2500);
    expect(store.goals.protein, 180);
    expect(store.goals.goalWeight, 170);
  });

  test('Resets nutrition goals when user signs out', () async {
    store.save(const NutritionGoals(
      calories: 2500,
      protein: 180,
    ));

    store.bind(null);

    expect(store.goals.calories, 2000);
    expect(store.goals.protein, 150);
  });
}
