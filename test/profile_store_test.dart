import 'package:bjj_app/models/user_profile.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _saved = UserProfile(
  name: 'Casey',
  belt: 'Purple',
  ageRange: '35-44',
  weeklyGoal: 6,
  fitnessGoal: 'Improve guard retention',
  nutritionGoal: 'Pack a post-training meal',
);

DocumentReference<Map<String, dynamic>> _document(
  FirebaseFirestore firestore,
  String uid,
) => firestore.doc('users/$uid/settings/profile');

Future<void> _waitFor(ProfileStore store, bool Function() ready) async {
  if (ready()) return;
  await Stream<void>.multi((controller) {
    void onChange() {
      if (ready()) controller.add(null);
    }

    store.addListener(onChange);
    controller.onCancel = () => store.removeListener(onChange);
  }).first;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ProfileStore store;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    store = ProfileStore(firestore: firestore);
    addTearDown(store.dispose);
  });

  test('Saves six fields and loads them in a fresh store', () async {
    await firestore.doc('users/first').set({'role': 'member'});
    store.bind('first', authName: 'Auth name');
    expect(store.loading, isTrue);
    await _waitFor(store, () => store.hasLoaded);

    await store.save(_saved, account: store.account);
    await _waitFor(store, () => store.profile.weeklyGoal == 6);
    expect((await _document(firestore, 'first').get()).data(), {
      'name': 'Casey',
      'belt': 'Purple',
      'ageRange': '35-44',
      'weeklyGoal': 6,
      'fitnessGoal': 'Improve guard retention',
      'nutritionGoal': 'Pack a post-training meal',
    });
    expect((await firestore.doc('users/first').get()).data(), {
      'role': 'member',
    });

    final reopened = ProfileStore(firestore: firestore);
    addTearDown(reopened.dispose);
    reopened.bind('first', authName: 'Auth name');
    await _waitFor(reopened, () => reopened.hasLoaded);
    expect(reopened.profile.toMap(), _saved.toMap());
  });

  test(
    'A missing profile uses the Auth name without creating a document',
    () async {
      store.bind('first', authName: '  Registration name  ');
      await _waitFor(store, () => store.hasLoaded);
      expect(store.loading, isFalse);
      expect(store.profile.name, 'Registration name');
      expect(store.profile.weeklyGoal, 4);
      expect(store.profile.belt, 'White');
      expect((await _document(firestore, 'first').get()).exists, isFalse);

      store.refreshAuthName('other', 'Wrong account');
      expect(store.profile.name, 'Registration name');
      store.bind('first', authName: 'Updated Auth name');
      expect(store.profile.name, 'Updated Auth name');
      expect(store.hasLoaded, isTrue);

      await store.save(_saved, account: store.account);
      await _waitFor(store, () => store.profile.name == 'Casey');
      store.refreshAuthName('first', 'Subsequent Auth name');
      expect(store.profile.name, 'Casey');
    },
  );

  test('Decodes malformed fields and reacts to valid goal updates', () async {
    final doc = _document(firestore, 'first');
    await doc.set({
      'name': '   ',
      'belt': 'Unknown',
      'ageRange': 33,
      'weeklyGoal': 19,
      'fitnessGoal': ['Unexpected list'],
      'nutritionGoal': 'Keep the good field',
    });
    store.bind('first', authName: 'Fallback');
    await _waitFor(store, () => store.hasLoaded);
    expect(store.profile.toMap(), {
      'name': 'Fallback',
      'belt': 'White',
      'ageRange': '25-34',
      'weeklyGoal': 4,
      'fitnessGoal': '',
      'nutritionGoal': 'Keep the good field',
    });
    for (final value in [null, '7', 2.5, 0, 8]) {
      expect(UserProfile.fromMap({'weeklyGoal': value}).weeklyGoal, 4);
    }
    await doc.update({'weeklyGoal': 1});
    await _waitFor(store, () => store.profile.weeklyGoal == 1);
    await doc.update({'weeklyGoal': 7});
    await _waitFor(store, () => store.profile.weeklyGoal == 7);

    for (final invalid in [0, 8]) {
      await expectLater(
        store.save(
          _saved.copyWith(weeklyGoal: invalid),
          account: store.account,
        ),
        throwsArgumentError,
      );
    }
    expect((await doc.get()).data()!['weeklyGoal'], 7);
  });

  test('Switching accounts clears old data and rejects stale drafts', () async {
    await _document(firestore, 'first').set(_saved.toMap());
    store.bind('first');
    await _waitFor(store, () => store.hasLoaded);
    final firstAccount = store.account;
    expect(store.profile.name, 'Casey');

    store.bind('second', authName: 'Second athlete');
    expect(store.profile.name, 'Second athlete');
    expect(store.profile.weeklyGoal, 4);
    await expectLater(
      store.save(_saved, account: firstAccount),
      throwsStateError,
    );
    await _waitFor(store, () => store.hasLoaded);
    await store.save(
      store.profile.copyWith(weeklyGoal: 2),
      account: store.account,
    );
    expect((await _document(firestore, 'first').get()).data(), _saved.toMap());
    expect(
      (await _document(firestore, 'second').get()).data()!['weeklyGoal'],
      2,
    );

    store.bind(null);
    expect(store.profile.name, 'Athlete');
    expect(store.profile.weeklyGoal, 4);
    expect(store.hasLoaded, isFalse);
    expect(store.loading, isFalse);
    store.bind('first');
    await _waitFor(store, () => store.hasLoaded);
    expect(store.profile.toMap(), _saved.toMap());
  });
}
