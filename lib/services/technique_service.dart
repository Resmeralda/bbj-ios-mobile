import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/technique.dart';

class TechniqueService {
  TechniqueService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Technique>> getTechniques() {
    return _db
        .collection('techniques')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Technique.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Technique>> getTechniquesByCategory(String category) {
    if (category == 'All') {
      return getTechniques();
    }

    return _db
        .collection('techniques')
        .where('category', isEqualTo: category)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Technique.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Technique?> watchTechnique(String id) =>
      _db.collection('techniques').doc(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : Technique.fromMap(doc.id, data);
      });
}
