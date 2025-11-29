import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hymn.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _hymnalsCollection = 'hymnals';

  // Get all hymnals
  Stream<List<Hymn>> getHymnals() {
    return _firestore
        .collection(_hymnalsCollection)
        .orderBy('number')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Hymn.fromJson(doc.id, doc.data()))
          .toList();
    });
  }

  // Get a single hymnal by ID
  Future<Hymn?> getHymnById(String id) async {
    try {
      final doc = await _firestore.collection(_hymnalsCollection).doc(id).get();
      if (doc.exists) {
        return Hymn.fromJson(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting hymn: $e');
      return null;
    }
  }

  // Get a single hymnal by number
  Future<Hymn?> getHymnByNumber(int number) async {
    try {
      final querySnapshot = await _firestore
          .collection(_hymnalsCollection)
          .where('number', isEqualTo: number)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Hymn.fromJson(doc.id, doc.data());
      }
      return null;
    } catch (e) {
      print('Error getting hymn by number: $e');
      return null;
    }
  }

  // Search hymnals by title
  Stream<List<Hymn>> searchHymnals(String query) {
    return _firestore
        .collection(_hymnalsCollection)
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Hymn.fromJson(doc.id, doc.data()))
          .toList();
    });
  }
}
