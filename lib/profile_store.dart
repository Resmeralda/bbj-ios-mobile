import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models/user_profile.dart';

class ProfileStore extends ChangeNotifier {
  ProfileStore({this._firestore});

  final FirebaseFirestore? _firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String? _uid;
  String _fallbackName = 'Athlete';
  Map<String, dynamic> _data = {};
  Object _account = Object();

  Object get account => _account;
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;
  bool _loading = false;
  bool get loading => _loading;
  String? _loadError;
  String? get loadError => _loadError;

  UserProfile get profile =>
      UserProfile.fromMap(_data, fallbackName: _fallbackName);

  DocumentReference<Map<String, dynamic>> _document(String uid) =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('profile');

  void bind(String? uid, {String? authName}) {
    if (uid == _uid) {
      if (uid != null) refreshAuthName(uid, authName);
      return;
    }
    _subscription?.cancel();
    _subscription = null;
    _account = Object();
    _uid = uid;
    _fallbackName = _nameOrDefault(authName);
    _data = {};
    _hasLoaded = false;
    _loadError = null;
    _loading = uid != null;
    if (uid != null) _listen(uid);
    notifyListeners();
  }

  String _nameOrDefault(String? authName) {
    final name = authName?.trim() ?? '';
    return name.isEmpty ? 'Athlete' : name;
  }

  void refreshAuthName(String uid, String? authName) {
    if (uid != _uid) return;
    final name = _nameOrDefault(authName);
    if (name == _fallbackName) return;
    _fallbackName = name;
    notifyListeners();
  }

  void retryLoad() {
    final uid = _uid;
    if (uid == null || _loading) return;
    _subscription?.cancel();
    _loadError = null;
    _loading = true;
    _listen(uid);
    notifyListeners();
  }

  void _listen(String uid) {
    final account = _account;
    _subscription = _document(uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (_account != account || snapshot.metadata.hasPendingWrites) {
              return;
            }
            // A cache miss cannot establish that this account has no profile.
            if (!snapshot.exists && snapshot.metadata.isFromCache) return;
            _data = snapshot.data() ?? {};
            _hasLoaded = true;
            _loading = false;
            _loadError = null;
            notifyListeners();
          },
          onError: (Object error) {
            if (_account != account) return;
            _loading = false;
            _loadError = 'Could not load your profile.';
            notifyListeners();
          },
        );
  }

  Future<void> save(UserProfile draft, {required Object account}) async {
    final uid = _uid;
    if (uid == null || account != _account || !_hasLoaded) {
      throw StateError('The profile is not ready to save.');
    }
    if (!UserProfile.validWeeklyGoal(draft.weeklyGoal)) {
      throw ArgumentError.value(draft.weeklyGoal, 'weeklyGoal');
    }
    await _document(uid).set(draft.toMap());
  }

  @override
  void dispose() {
    _account = Object();
    _subscription?.cancel();
    super.dispose();
  }
}

final profileStore = ProfileStore();
