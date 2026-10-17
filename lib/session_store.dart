import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models/training_session.dart';

/// Training sessions for the signed-in user, stored in Cloud Firestore at
/// users/{uid}/sessions/{id}. Screens read [sessions] and call
/// add / update / delete; changes appear immediately through the
/// Firestore snapshot listener (it fires locally before the server confirms).
class SessionStore extends ChangeNotifier {
  List<TrainingSession> _sessions = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;

  bool loading = false;
  String? error;

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('sessions');

  /// Call whenever the signed-in user changes (null = signed out).
  void bind(String? uid) {
    if (uid == _uid) return;
    _sub?.cancel();
    _sub = null;
    _uid = uid;
    _sessions = [];
    error = null;

    if (uid == null) {
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();
    _sub = _col!.snapshots().listen(
      (snap) {
        _sessions = [
          for (final d in snap.docs) TrainingSession.fromMap(d.id, d.data()),
        ];
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
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

  /// Sessions since Monday of the current week, newest first.
  List<TrainingSession> get thisWeek {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return sessions.where((s) => !s.date.isBefore(monday)).toList();
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
    op()?.catchError((Object e) {
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
