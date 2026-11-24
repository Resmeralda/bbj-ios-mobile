import 'package:bjj_app/data/recovery_settings_store.dart';
import 'package:bjj_app/models/recovery_settings.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Loads defaults, persists a custom goal, and isolates accounts',
    () async {
      final firestore = FakeFirebaseFirestore();
      final store = RecoverySettingsStore(firestore: firestore);
      addTearDown(store.dispose);
      final load = store.bind('first');
      expect(store.loading, isTrue);
      expect(store.settings, isNull);
      await load;
      expect(store.loading, isFalse);
      expect(store.settings!.toMap(), {'sleepGoalHours': 8.0, 'showHrv': true});

      final firstAccount = store.account;
      await store.save(
        const RecoverySettings(sleepGoalHours: 7.5, showHrv: false),
        account: firstAccount,
      );
      expect(
        (await firestore.doc('users/first/settings/recovery').get()).data(),
        {'sleepGoalHours': 7.5, 'showHrv': false},
      );
      final otherLoad = store.bind('second');
      expect(store.settings, isNull);
      await otherLoad;
      expect(store.settings!.sleepGoalHours, 8);
      await expectLater(
        store.save(const RecoverySettings(), account: firstAccount),
        throwsStateError,
      );
      expect(
        (await firestore.doc('users/second/settings/recovery').get()).exists,
        isFalse,
      );
      await store.bind(null);
      expect(store.settings, isNull);
      expect(store.loading, isFalse);
      await store.load();
      await store.bind('first');
      await store.bind('first');
      expect(store.settings!.sleepGoalHours, 7.5);
      expect(store.settings!.showHrv, isFalse);
    },
  );

  test(
    'Ignores an earlier read or save completed during an account change',
    () async {
      final firestore = FakeFirebaseFirestore();
      final store = RecoverySettingsStore(firestore: firestore);
      addTearDown(store.dispose);
      await firestore.doc('users/first/settings/recovery').set({
        'sleepGoalHours': 6,
      });
      await firestore.doc('users/second/settings/recovery').set({
        'sleepGoalHours': 9,
      });

      final firstLoad = store.bind('first');
      final secondLoad = store.bind('second');
      await Future.wait([firstLoad, secondLoad]);
      expect(store.settings!.sleepGoalHours, 9);

      final save = store.save(
        const RecoverySettings(sleepGoalHours: 10),
        account: store.account,
      );
      await store.bind('first');
      await save;
      expect(store.settings!.sleepGoalHours, 6);
      expect(
        (await firestore.doc('users/second/settings/recovery').get())
            .data()!['sleepGoalHours'],
        10,
      );
    },
  );

  test('Rejects invalid goals and safely reads malformed settings', () async {
    final firestore = FakeFirebaseFirestore();
    final store = RecoverySettingsStore(firestore: firestore);
    addTearDown(store.dispose);
    final document = firestore.doc('users/athlete/settings/recovery');
    await document.set({'sleepGoalHours': 'bad data', 'showHrv': 1});
    await store.bind('athlete');
    expect(store.settings!.toMap(), const RecoverySettings().toMap());
    for (final goal in [0.0, 25.0, double.infinity, double.nan]) {
      await expectLater(
        store.save(
          RecoverySettings(sleepGoalHours: goal),
          account: store.account,
        ),
        throwsArgumentError,
      );
    }
    expect((await document.get()).data()!['sleepGoalHours'], 'bad data');
  });
}
