import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:therapii/models/user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  User? _userFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;

    final merged = Map<String, dynamic>.from(data);
    final rawId = merged['id'];
    if (rawId is String) {
      if (rawId.trim().isEmpty) {
        merged['id'] = doc.id;
      }
    } else if (rawId == null) {
      merged['id'] = doc.id;
    } else {
      merged['id'] = rawId.toString();
    }

    return User.fromJson(merged);
  }

  // Create a new user
  Future<void> createUser(User user) async {
    try {
      await _firestore.collection(_collection).doc(user.id).set(user.toJson());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Get user by ID
  Future<User?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return null;
      return _userFromSnapshot(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update user
  Future<void> updateUser(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await _firestore.collection(_collection).doc(user.id).update(updatedUser.toJson());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return _userFromSnapshot(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }

  // Stream user data for real-time updates
  Stream<User?> streamUser(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? _userFromSnapshot(doc) : null);
  }

  // Update user profile fields
  Future<void> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? avatarUrl,
    bool? isTherapist,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': Timestamp.fromDate(DateTime.now()),
      };
      
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (isTherapist != null) updates['is_therapist'] = isTherapist;
      
      await _firestore.collection(_collection).doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Link patient to therapist
  Future<void> linkPatientToTherapist({
    required String userId,
    required String therapistId,
  }) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'therapist_id': therapistId,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to link patient to therapist: $e');
    }
  }

  Future<void> savePatientOnboardingData({
    required String userId,
    required Map<String, dynamic> data,
    bool completed = true,
  }) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'patient_onboarding_data': data,
        'patient_onboarding_completed': completed,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to save onboarding data: $e');
    }
  }

  // Get patients for therapist
  Future<List<User>> getPatientsForTherapist(String therapistId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('therapist_id', isEqualTo: therapistId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => _userFromSnapshot(doc))
          .whereType<User>()
          .toList();
    } catch (e) {
      throw Exception('Failed to get patients: $e');
    }
  }

  // Batch fetch users by IDs (chunks of 10 due to Firestore constraints)
  Future<List<User>> getUsersByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];
      final List<User> users = [];
      const int chunkSize = 10;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
        final snapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        users.addAll(snapshot.docs.map((doc) => _userFromSnapshot(doc)).whereType<User>());
      }
      return users;
    } catch (e) {
      throw Exception('Failed to batch fetch users: $e');
    }
  }
}