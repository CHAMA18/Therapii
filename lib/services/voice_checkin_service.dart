import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:therapii/models/voice_checkin.dart';
import 'package:therapii/services/voice_bytes_loader.dart';

class VoiceCheckinService {
  static const String _collection = 'voice_checkins';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col() => _firestore.collection(_collection);

  Future<String> uploadAndShareRecording({
    required String localPath,
    required String patientId,
    required String therapistId,
    required int durationSeconds,
  }) async {
    // Load bytes (mobile/desktop only; web throws UnsupportedError)
    final Uint8List bytes = await loadRecordedFileBytes(localPath);

    // Build a path: voice_checkins/{patientId}/{therapistId}/{ts}_{rand}.m4a
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    final fileName = 'voice_${ts}_$rand.m4a';
    final storagePath = 'voice_checkins/$patientId/$therapistId/$fileName';

    // Upload to Firebase Storage
    final ref = _storage.ref().child(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: 'audio/m4a'));
    final downloadUrl = await ref.getDownloadURL();

    // Save Firestore record
    final docRef = await _col().add({
      'patient_id': patientId,
      'therapist_id': therapistId,
      'created_at': Timestamp.fromDate(DateTime.now()),
      'duration_seconds': durationSeconds,
      'audio_url': downloadUrl,
      'storage_path': ref.fullPath,
      'share_with_therapist': true,
    });

    return docRef.id;
  }

  Stream<List<VoiceCheckin>> streamTherapistCheckins({
    required String therapistId,
    int limit = 20,
  }) {
    return _col()
        .where('therapist_id', isEqualTo: therapistId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(VoiceCheckin.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<VoiceCheckin>> streamPatientCheckins({
    required String therapistId,
    required String patientId,
    int limit = 20,
  }) {
    return _col()
        .where('therapist_id', isEqualTo: therapistId)
        .where('patient_id', isEqualTo: patientId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(VoiceCheckin.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> deleteCheckin(String checkinId, {required String therapistId}) async {
    // Safety: ensure the document belongs to therapist before delete
    final doc = await _col().doc(checkinId).get();
    if (!doc.exists) return;
    final data = doc.data() ?? {};
    if ((data['therapist_id'] ?? '') != therapistId) {
      throw Exception('Permission denied.');
    }
    final storagePath = (data['storage_path'] ?? '').toString();
    await _col().doc(checkinId).delete();
    if (storagePath.isNotEmpty) {
      try {
        await _storage.ref().child(storagePath).delete();
      } catch (_) {
        // ignore cleanup errors
      }
    }
  }
}
