import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum UserRole {
  student('Student'),
  trainer('Trainer'),
  administrator('Administrator');

  const UserRole(this.label);
  final String label;
}

enum RoleStatus { signedOut, loading, verified, unavailable }

typedef RoleDocument = ({bool exists, Object? role, bool verified});

class RoleStore extends ChangeNotifier {
  RoleStore({FirebaseFirestore? firestore})
    : this.withWatch(
        (uid) => (firestore ?? FirebaseFirestore.instance)
            .collection('user_roles')
            .doc(uid)
            .snapshots(includeMetadataChanges: true)
            .map(
              (snapshot) => (
                exists: snapshot.exists,
                role: snapshot.data()?['role'],
                verified:
                    !snapshot.metadata.isFromCache &&
                    !snapshot.metadata.hasPendingWrites,
              ),
            ),
      );

  RoleStore.withWatch(this._watch);

  final Stream<RoleDocument> Function(String uid) _watch;
  StreamSubscription<RoleDocument>? _subscription;
  String? _uid;
  Object _binding = Object();
  Object _access = Object();
  Object get access => _access;
  RoleStatus _status = RoleStatus.signedOut;
  UserRole? _role;

  RoleStatus statusFor(String? uid) => uid == null
      ? RoleStatus.signedOut
      : uid == _uid
      ? _status
      : RoleStatus.loading;

  UserRole? verifiedRoleFor(String? uid) =>
      statusFor(uid) == RoleStatus.verified ? _role : null;

  void bind(String? uid) {
    if (_uid == uid) return;
    final binding = _binding = Object();
    _access = Object();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _uid = uid;
    _update(uid == null ? RoleStatus.signedOut : RoleStatus.loading);
    if (uid == null || binding != _binding) return;

    _subscription = _watch(uid).listen(
      (document) {
        if (binding != _binding) return;
        final role = switch (document) {
          (exists: false, verified: true, role: _) => UserRole.student,
          (exists: true, verified: true, role: 'trainer') => UserRole.trainer,
          (exists: true, verified: true, role: 'admin') =>
            UserRole.administrator,
          _ => null,
        };
        _update(
          role == null ? RoleStatus.unavailable : RoleStatus.verified,
          role,
        );
      },
      onError: (Object _) {
        if (binding == _binding) _update(RoleStatus.unavailable);
      },
      onDone: () {
        if (binding == _binding) _update(RoleStatus.unavailable);
      },
    );
  }

  void _update(RoleStatus status, [UserRole? role]) {
    if (status != _status || role != _role) _access = Object();
    _status = status;
    _role = role;
    notifyListeners();
  }

  @override
  void dispose() {
    _binding = Object();
    _access = Object();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final roleStore = RoleStore();
