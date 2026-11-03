
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_app/data/collection_store.dart';

class TestFood {
  final String id;
  final String name;
  final int calories;

  TestFood(this.id, this.name, this.calories);

  factory TestFood.fromMap(String id, Map<String, dynamic> data) {
    return TestFood(id, data['name'] as String, data['calories'] as int);
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
  };
}

void main() {
  late FakeFirebaseFirestore firestore;
  late CollectionStore<TestFood> store;

  setUp(() {
    firestore = FakeFirebaseFirestore();

    store = CollectionStore<TestFood>(
      firestore: firestore,
      path: 'food_log',
      fromMap: TestFood.fromMap,
      toMap: (food) => food.toMap(),
      idOf: (food) => food.id,
      compare: (a, b) => a.name.compareTo(b.name),
    );

    store.bind('test-user');
  });

  tearDown(() {
    store.dispose();
  });

  test('Saves a food entry to Firestore', () async {
    store.save(TestFood('food-1', 'Avocado Toast', 300));

    final snapshot = await firestore
        .collection('users')
        .doc('test-user')
        .collection('food_log')
        .doc('food-1')
        .get();

    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['name'], 'Avocado Toast');
    expect(snapshot.data()?['calories'], 300);
  });

  test('Loads food entries from Firestore', () async {
    await firestore
        .collection('users')
        .doc('test-user')
        .collection('food_log')
        .doc('food-1')
        .set({'name': 'Avocado Toast', 'calories': 300});

    await pumpEventQueue();

    expect(store.items.length, 1);
    expect(store.items.first.name, 'Avocado Toast');
  });

  test('Deletes a food entry from Firestore', () async {
    await firestore
        .collection('users')
        .doc('test-user')
        .collection('food_log')
        .doc('food-1')
        .set({'name': 'Avocado Toast', 'calories': 300});

    store.delete('food-1');

    await pumpEventQueue();

    final snapshot = await firestore
        .collection('users')
        .doc('test-user')
        .collection('food_log')
        .doc('food-1')
        .get();

    expect(snapshot.exists, isFalse);
  });

  test('Sorts food entries alphabetically', () async {
    final collection = firestore
        .collection('users')
        .doc('test-user')
        .collection('food_log');

    await collection.doc('food-2').set({
      'name': 'Banana',
      'calories': 100,
    });

    await collection.doc('food-1').set({
      'name': 'Avocado Toast',
      'calories': 300,
    });

    await pumpEventQueue();

    expect(store.items.length, 2);
    expect(store.items[0].name, 'Avocado Toast');
    expect(store.items[1].name, 'Banana');
  });

  test('Clears food entries when user signs out', () async {
    await firestore
        .collection('users')
        .doc('test-user')
        .collection('food_log')
        .doc('food-1')
        .set({
          'name': 'Avocado Toast',
          'calories': 300,
        });

    await pumpEventQueue();

    expect(store.items.length, 1);

    store.bind(null);

    expect(store.items, isEmpty);
    expect(store.loading, isFalse);
  });

}
