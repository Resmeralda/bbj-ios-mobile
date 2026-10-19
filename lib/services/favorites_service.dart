
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _favorites {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User must be signed in.');
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('favorites');
  }

  Stream<Set<String>> getFavorites() {
    return _favorites.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => doc.id)
          .toSet(),
    );
  }

  Future<void> toggleFavorite(
    String techniqueId,
    bool isFavorite,
  ) async {
    final reference = _favorites.doc(techniqueId);

    if (isFavorite) {
      await reference.delete();
    } else {
      await reference.set({
        'techniqueId': techniqueId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
