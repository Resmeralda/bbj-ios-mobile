import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PracticedService {
  PracticedService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _practiced {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User must be signed in.');
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('practicedTechniques');
  }

  Stream<bool> isPracticed(String techniqueId) {
    return _practiced
        .doc(techniqueId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> setPracticed(String techniqueId, bool practiced) async {
    final reference = _practiced.doc(techniqueId);

    if (practiced) {
      await reference.set({
        'techniqueId': techniqueId,
        'practicedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.delete();
    }
  }
}
