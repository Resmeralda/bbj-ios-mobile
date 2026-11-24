import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/recovery_settings.dart';

class RecoverySettingsStore extends ChangeNotifier {
  RecoverySettingsStore({this._firestore});

  final FirebaseFirestore? _firestore;
  String? _uid;
  Object _account = Object();
  RecoverySettings? _settings;
  bool _loading = false;
  String? _error;

  Object get account => _account;
  RecoverySettings? get settings => _settings;
  bool get loading => _loading;
  String? get error => _error;

  DocumentReference<Map<String, dynamic>> _document(String uid) =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('recovery');

  Future<void> bind(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    _account = Object();
    _settings = null;
    _loading = false;
    _error = null;
    if (uid == null) {
      notifyListeners();
      return;
    }
    await load();
  }

  Future<void> load() async {
    final uid = _uid;
    if (uid == null || _loading) return;
    final account = _account;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _document(uid).get();
      if (account != _account) return;
      _settings = RecoverySettings.fromMap(snapshot.data());
    } on Exception {
      if (account != _account) return;
      _error = 'Could not load recovery settings.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> save(RecoverySettings draft, {required Object account}) async {
    final uid = _uid;
    if (uid == null || account != _account || _settings == null) {
      throw StateError('Recovery settings are not ready to save.');
    }
    if (!RecoverySettings.isValidSleepGoal(draft.sleepGoalHours)) {
      throw ArgumentError.value(draft.sleepGoalHours, 'sleepGoalHours');
    }
    await _document(uid).set(draft.toMap());
    if (account != _account) return;
    _settings = draft;
    notifyListeners();
  }

  @override
  void dispose() {
    _account = Object();
    super.dispose();
  }
}

final recoverySettingsStore = RecoverySettingsStore();
