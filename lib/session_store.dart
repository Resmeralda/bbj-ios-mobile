import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models/training_session.dart';

/// Training sessions for the signed-in user, stored in Cloud Firestore at
/// users/{uid}/sessions/{id}. Screens read [sessions] and call
/// add / update / delete; changes appear immediately through the
/// Firestore snapshot listener (it fires locally before the server confirms).
class SessionStore extends ChangeNotifier {
  SessionStore({this._firestore});

  final FirebaseFirestore? _firestore;
  List<TrainingSession> _sessions = [];
  StreamSubscription<List<TrainingSession>>? _sub;
  String? _uid;
  Object _account = Object();
  Object get account => _account;

  bool loading = false;
  String? error;

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : (_firestore ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(_uid)
            .collection('sessions');

  /// Call whenever the signed-in user changes (null = signed out).
  void bind(String? uid) {
    if (uid == _uid) return;
    _sub?.cancel();
    _sub = null;
    _uid = uid;
    _account = Object();
    _sessions = [];
    error = null;

    if (uid == null) {
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();
    final account = _account;
    _sub = _col!
        .snapshots()
        .map(
          (snap) => [
            for (final d in snap.docs) TrainingSession.fromMap(d.id, d.data()),
          ],
        )
        .listen(
          (sessions) {
            if (account != _account) return;
            _sessions = sessions;
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object e) {
            if (account != _account) return;
            debugPrint('Session sync failed: $e');
            loading = false;
            error = 'Could not load sessions. Check your connection.';
            notifyListeners();
          },
        );
  }

  /// Newest first.
  List<TrainingSession> get sessions =>
      [..._sessions]..sort((a, b) => b.date.compareTo(a.date));

  /// Sessions in the local Monday–Sunday week, newest first.
  List<TrainingSession> get thisWeek => sessionsForWeek(DateTime.now());

  List<TrainingSession> sessionsForWeek(DateTime date) {
    final local = date.toLocal();
    final monday = DateTime(
      local.year,
      local.month,
      local.day - local.weekday + 1,
    );
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    return sessions
        .where((s) => !s.date.isBefore(monday) && s.date.isBefore(nextMonday))
        .toList();
  }

  String newId() =>
      _col?.doc().id ?? DateTime.now().microsecondsSinceEpoch.toString();

  // Writes are not awaited: the snapshot listener updates the UI right away
  // and Firestore syncs in the background (also works offline).
  void add(TrainingSession s) => _write(() => _col?.doc(s.id).set(s.toMap()));

  void update(TrainingSession s) =>
      _write(() => _col?.doc(s.id).set(s.toMap()));

  void delete(String id) => _write(() => _col?.doc(id).delete());

  void _write(Future<void>? Function() op) {
    final account = _account;
    op()?.catchError((Object e) {
      if (account != _account) return;
      debugPrint('Session write failed: $e');
      error = 'Could not save your changes.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final sessionStore = SessionStore();
