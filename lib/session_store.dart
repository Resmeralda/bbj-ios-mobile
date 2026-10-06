import 'package:flutter/foundation.dart';

import 'models/training_session.dart';

/// In-memory session list shared across screens.
/// TODO: replace with Cloud Firestore (users/{uid}/sessions).
class SessionStore extends ChangeNotifier {
  final List<TrainingSession> _sessions = _seed();

  static List<TrainingSession> _seed() {
    final now = DateTime.now();
    DateTime ago(int days) => DateTime(
      now.year,
      now.month,
      now.day,
      18,
    ).subtract(Duration(days: days));
    return [
      TrainingSession(
        id: 's1',
        type: 'Gi Class',
        date: ago(0),
        hours: 1.5,
        rounds: 5,
        techniques: 'Guard passing, side control',
        notes: '',
      ),
      TrainingSession(
        id: 's2',
        type: 'Open Mat',
        date: ago(3),
        hours: 2.0,
        rounds: 8,
        techniques: 'Sweeps and transitions',
        notes: 'Felt sharp on top.',
      ),
      TrainingSession(
        id: 's3',
        type: 'No-Gi Class',
        date: ago(6),
        hours: 1.0,
        rounds: 4,
        techniques: 'Takedown defense, back control',
        notes: '',
      ),
    ];
  }

  /// Newest first.
  List<TrainingSession> get sessions =>
      [..._sessions]..sort((a, b) => b.date.compareTo(a.date));

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void add(TrainingSession s) {
    _sessions.add(s);
    notifyListeners();
  }

  void update(TrainingSession s) {
    final i = _sessions.indexWhere((e) => e.id == s.id);
    if (i != -1) _sessions[i] = s;
    notifyListeners();
  }

  void delete(String id) {
    _sessions.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}

final sessionStore = SessionStore();
