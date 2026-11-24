import 'dart:async';

import 'package:bjj_app/data/role_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

RoleDocument document(
  Object? role, {
  bool exists = true,
  bool verified = true,
}) => (exists: exists, role: role, verified: verified);

void main() {
  test(
    'Reads the signed-in user’s role document and follows changes',
    () async {
      final firestore = FakeFirebaseFirestore();
      final store = RoleStore(firestore: firestore);
      addTearDown(store.dispose);
      final role = firestore.doc('user_roles/athlete');

      store.bind('athlete');
      expect(store.statusFor('athlete'), RoleStatus.loading);
      await pumpEventQueue();
      expect(store.verifiedRoleFor('athlete'), UserRole.student);
      for (final (value, expected) in [
        ('trainer', UserRole.trainer),
        ('admin', UserRole.administrator),
        ('unknown', null),
        (true, null),
        (null, null),
      ]) {
        await role.set({'role': value});
        await pumpEventQueue();
        expect(store.verifiedRoleFor('athlete'), expected);
      }
      await role.delete();
      await pumpEventQueue();
      expect(store.verifiedRoleFor('athlete'), UserRole.student);
      store.bind(null);
      expect(store.statusFor(null), RoleStatus.signedOut);
      expect(store.verifiedRoleFor(null), isNull);
    },
  );

  test('Cache and pending writes cannot establish or retain a role', () async {
    final snapshots = StreamController<RoleDocument>(sync: true);
    final store = RoleStore.withWatch((_) => snapshots.stream);
    addTearDown(store.dispose);
    store.bind('athlete');
    snapshots.add(document('admin', verified: false));
    expect(store.statusFor('athlete'), RoleStatus.unavailable);
    expect(store.verifiedRoleFor('athlete'), isNull);
    snapshots.add(document(null, exists: false, verified: false));
    expect(store.verifiedRoleFor('athlete'), isNull);
    snapshots.add(document('admin'));
    expect(store.verifiedRoleFor('athlete'), UserRole.administrator);
    snapshots.add(document('admin', verified: false));
    expect(store.verifiedRoleFor('athlete'), isNull);
    snapshots.add(document('trainer'));
    expect(store.verifiedRoleFor('athlete'), UserRole.trainer);
    snapshots.addError(StateError('Lookup failed'));
    expect(store.statusFor('athlete'), RoleStatus.unavailable);
    expect(store.verifiedRoleFor('athlete'), isNull);
    snapshots.add(document('admin'));
    await snapshots.close();
    expect(store.verifiedRoleFor('athlete'), isNull);
  });

  test(
    'An account switch clears privileges before queued results arrive',
    () async {
      final first = StreamController<RoleDocument>();
      final second = StreamController<RoleDocument>();
      final store = RoleStore.withWatch(
        (uid) => uid == 'first' ? first.stream : second.stream,
      );
      addTearDown(store.dispose);
      store.bind('first');
      first.add(document('admin'));
      await pumpEventQueue();
      expect(store.verifiedRoleFor('first'), UserRole.administrator);
      expect(store.verifiedRoleFor('second'), isNull);

      first.add(document('admin'));
      store.bind('second');
      expect(store.verifiedRoleFor('first'), isNull);
      expect(store.statusFor('second'), RoleStatus.loading);
      second.add(document('trainer'));
      await pumpEventQueue();
      expect(store.verifiedRoleFor('second'), UserRole.trainer);
      second.add(document('admin'));
      store.bind(null);
      await pumpEventQueue();
      expect(store.verifiedRoleFor('second'), isNull);
      await first.close();
      await second.close();
    },
  );
}
