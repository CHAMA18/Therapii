import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:therapii/models/therapist.dart';

class TherapistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'therapists';

  // Create a new therapist profile
  Future<void> createTherapist(Therapist therapist) async {
    try {
      await _firestore.collection(_collection).doc(therapist.id).set(therapist.toJson());
    } catch (e) {
      throw Exception('Failed to create therapist: $e');
    }
  }

  // Get therapist by ID
  Future<Therapist?> getTherapist(String therapistId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(therapistId).get();
      if (doc.exists && doc.data() != null) {
        return Therapist.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get therapist: $e');
    }
  }

  // Update therapist
  Future<void> updateTherapist(Therapist therapist) async {
    try {
      final updatedTherapist = therapist.copyWith(updatedAt: DateTime.now());
      await _firestore.collection(_collection).doc(therapist.id).update(updatedTherapist.toJson());
    } catch (e) {
      throw Exception('Failed to update therapist: $e');
    }
  }

  // Delete therapist
  Future<void> deleteTherapist(String therapistId) async {
    try {
      await _firestore.collection(_collection).doc(therapistId).delete();
    } catch (e) {
      throw Exception('Failed to delete therapist: $e');
    }
  }

  // Get all available therapists
  Future<List<Therapist>> getAvailableTherapists({int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('is_available', isEqualTo: true)
          .get();

      final list = querySnapshot.docs
          .map((doc) => Therapist.fromJson(doc.data()))
          .toList();
      list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get available therapists: $e');
    }
  }

  // Search therapists by specialization
  Future<List<Therapist>> searchTherapistsBySpecialization(
    String specialization, {
    int limit = 20,
  }) async {
    try {
      // Avoid composite index: query on one field and filter locally
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('specialization', isEqualTo: specialization)
          .get();

      final list = querySnapshot.docs
          .map((doc) => Therapist.fromJson(doc.data()))
          .where((t) => t.isAvailable == true)
          .toList();
      list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to search therapists: $e');
    }
  }

  // Get top rated therapists
  Future<List<Therapist>> getTopRatedTherapists({int limit = 10}) async {
    try {
      // Avoid composite index: query on one field and filter locally
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('is_verified', isEqualTo: true)
          .get();

      final list = querySnapshot.docs
          .map((doc) => Therapist.fromJson(doc.data()))
          .where((t) => t.isAvailable == true)
          .toList();
      list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get top rated therapists: $e');
    }
  }

  // Stream therapist data for real-time updates
  Stream<Therapist?> streamTherapist(String therapistId) {
    return _firestore
        .collection(_collection)
        .doc(therapistId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? Therapist.fromJson(doc.data()!)
            : null);
  }

  // Update therapist availability
  Future<void> updateAvailability(String therapistId, bool isAvailable) async {
    try {
      await _firestore.collection(_collection).doc(therapistId).update({
        'is_available': isAvailable,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update availability: $e');
    }
  }

  // Update therapist rating
  Future<void> updateRating(String therapistId, double newRating, int newReviewCount) async {
    try {
      await _firestore.collection(_collection).doc(therapistId).update({
        'rating': newRating,
        'review_count': newReviewCount,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update rating: $e');
    }
  }

  // Get therapists by user ID (for therapists managing their profile)
  Future<Therapist?> getTherapistByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return Therapist.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get therapist by user ID: $e');
    }
  }
}