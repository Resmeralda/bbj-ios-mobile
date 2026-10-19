
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/technique.dart';

class TechniqueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Technique>> getTechniques() {
    return _db.collection('techniques').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Technique.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Stream<List<Technique>> getTechniquesByCategory(
    String category,
  ) {
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

  Future<Technique?> getTechnique(String id) async {
    final doc = await _db.collection('techniques').doc(id).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Technique.fromMap(doc.id, doc.data()!);
  }
}
