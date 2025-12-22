import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:therapii/models/invitation_code.dart';

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'invitation_codes';
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final Random _random = Random();
  
  // Holds a pending invitation when a patient verifies a code before authenticating
  // This lets us prefill signup and link post-auth.
  static InvitationCode? pendingInvitation;

  // Result for createInvitationAndSendEmail
  Future<CreateInvitationResult> createInvitationAndSendEmail({
    required String therapistId,
    required String patientEmail,
    required String patientFirstName,
    String patientLastName = '',
  }) async {
    try {
      final callable =
          _functions.httpsCallable('createInvitationAndSendEmail');
      final result = await callable.call({
        'therapistId': therapistId,
        'patientEmail': patientEmail,
        'patientFirstName': patientFirstName,
        'patientLastName': patientLastName,
      });

      final sanitized = _normalizeDynamicMap(result.data);
      final invitationId = sanitized['invitationId'] ?? sanitized['invitation_id'];
      final emailSent = sanitized['emailSent'] == true || sanitized['email_sent'] == true;

      // Prefer the function's payload and avoid direct Firestore access to comply
      // with restrictive security rules on client SDK.
      final invitationPayload = sanitized['invitation'];
      if (invitationPayload is Map) {
        final normalizedInvitation = _normalizeDynamicMap(invitationPayload);
        // Ensure essential fields are present
        if ((normalizedInvitation['id'] ?? '').toString().isEmpty &&
            invitationId is String && invitationId.isNotEmpty) {
          normalizedInvitation['id'] = invitationId;
        }
        normalizedInvitation.putIfAbsent('therapistId', () => therapistId);
        normalizedInvitation.putIfAbsent('therapist_id', () => therapistId);
        normalizedInvitation.putIfAbsent('patientEmail', () => patientEmail);
        normalizedInvitation.putIfAbsent('patient_email', () => patientEmail);
        normalizedInvitation.putIfAbsent('patientFirstName', () => patientFirstName);
        normalizedInvitation.putIfAbsent('patient_first_name', () => patientFirstName);
        normalizedInvitation.putIfAbsent('patientLastName', () => patientLastName);
        normalizedInvitation.putIfAbsent('patient_last_name', () => patientLastName);
        final inv = InvitationCode.fromJson(normalizedInvitation);
        return CreateInvitationResult(invitation: inv, emailSent: emailSent);
      }

      // If the function didn't return the invitation payload, fail fast with a
      // descriptive error instead of reading Firestore from the client.
      throw const InvitationException(
        'Invitation was created, but server did not return the invitation payload. Please redeploy functions to the latest version.',
      );
    } on InvitationException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToFirestore(e)) {
        final inv = await _createInvitationLocally(
          therapistId: therapistId,
          patientEmail: patientEmail,
          patientFirstName: patientFirstName,
          patientLastName: patientLastName,
        );
        return CreateInvitationResult(invitation: inv, emailSent: false);
      }

      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Cloud function error (${e.code})';

      String? detailString;
      final details = e.details;
      if (details is String && details.trim().isNotEmpty) {
        detailString = details;
      } else if (details is Map) {
        final normalized = _normalizeDynamicMap(details);
        final mapMessages = <String>[];
        final detailsMessage = normalized['message']?.toString();
        if (detailsMessage != null && detailsMessage.trim().isNotEmpty) {
          mapMessages.add(detailsMessage.trim());
        }
        final responseBody = normalized['responseBody'];
        if (responseBody is Map && responseBody['errors'] is List) {
          final errors = (responseBody['errors'] as List)
              .whereType<Map>()
              .map((err) => err['message']?.toString())
              .whereType<String>()
              .map((msg) => msg.trim())
              .where((msg) => msg.isNotEmpty)
              .toList();
          if (errors.isNotEmpty) {
            mapMessages.addAll(errors);
          }
        }
        if (mapMessages.isEmpty && normalized.isNotEmpty) {
          mapMessages.add(jsonEncode(normalized));
        }
        if (mapMessages.isNotEmpty) {
          detailString = mapMessages.join(' | ');
        }
      } else if (details != null) {
        try {
          detailString = jsonEncode(details);
        } catch (_) {
          detailString = details.toString();
        }
      }

      // Fetch any persisted error context to surface actionable info to the UI
      String? persistedMessage;
      try {
        final snapshot = await _firestore
            .collection('invitation_errors')
            .where('therapistId', isEqualTo: therapistId)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final docs = snapshot.docs
              .map((doc) => doc.data())
              .whereType<Map<String, dynamic>>()
              .cast<Map<String, dynamic>>()
              .toList();

          docs.sort((a, b) {
            final aTime = _extractDate(a['createdAt']);
            final bTime = _extractDate(b['createdAt']);
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          final latest = docs.firstWhere(
            (data) => (data['patientEmail'] ?? data['patient_email']) == patientEmail,
            orElse: () => docs.first,
          );
          final responseBody = latest['responseBody'];
          if (responseBody is Map && responseBody['errors'] is List) {
            final errors = (responseBody['errors'] as List)
                .map((err) => err is Map && err['message'] != null
                    ? err['message'].toString()
                    : err.toString())
                .where((msg) => msg.trim().isNotEmpty)
                .toList();
            if (errors.isNotEmpty) {
              persistedMessage = errors.join(' | ');
            }
          }

          persistedMessage ??= latest['message']?.toString();
        }
      } catch (_) {
        // Ignore lookup failures – we still have the function's error message.
      }

      final detailClean = detailString?.replaceAll('\n', ' ').trim();
      final combinedMessage = detailClean != null && detailClean.isNotEmpty
          && detailClean.toLowerCase() != message.toLowerCase()
          ? '$message – $detailClean'
          : message;

      final fullMessage = persistedMessage != null && persistedMessage.isNotEmpty
          ? '$combinedMessage (${persistedMessage.trim()})'
          : combinedMessage;

      throw InvitationException(fullMessage);
    } catch (e) {
      throw InvitationException('Failed to create invitation: $e');
    }
  }

  // Fallback path when the callable is unavailable; mirrors the backend logic.
  Future<InvitationCode> _createInvitationLocally({
    required String therapistId,
    required String patientEmail,
    required String patientFirstName,
    String patientLastName = '',
  }) async {
    final code = await _generateUniqueCode();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 48));
    final docRef = _firestore.collection(_collection).doc();

    final payload = <String, dynamic>{
      'id': docRef.id,
      'code': code,
      'therapist_id': therapistId,
      'patient_email': patientEmail,
      'patient_first_name': patientFirstName,
      'patient_last_name': patientLastName,
      'is_used': false,
      'created_at': Timestamp.fromDate(now),
      'expires_at': Timestamp.fromDate(expiresAt),
    };

    await docRef.set(payload);
    return InvitationCode.fromJson(payload);
  }

  Future<String> _generateUniqueCode() async {
    const maxAttempts = 20;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final code = (10000 + _random.nextInt(90000)).toString();
      final snapshot = await _firestore
          .collection(_collection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return code;
      }
    }

    throw const InvitationException('Unable to generate a unique invitation code');
  }

  bool _shouldFallbackToFirestore(FirebaseFunctionsException exception) {
    final normalizedCode = _normalizeFunctionsErrorCode(exception.code);
    if (_fallbackFunctionErrors.contains(normalizedCode)) return true;

    final normalizedMessage = _normalizeFunctionsErrorCode(exception.message);
    return _fallbackFunctionErrors.contains(normalizedMessage);
  }

  static const Set<String> _fallbackFunctionErrors = <String>{
    'internal',
    'unavailable',
    'deadline-exceeded',
    'unknown',
  };

  String _normalizeFunctionsErrorCode(dynamic code) {
    if (code == null) return '';
    var value = code.toString().trim();
    if (value.isEmpty) return '';

    value = value.replaceAll('/', '.');
    if (value.contains('.')) {
      value = value.split('.').last;
    }

    value = value.replaceAll(RegExp(r'[\s_:+]'), '-');
    value = value.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}-${match.group(2)}',
    );

    value = value.toLowerCase();

    const prefixes = [
      'functions-',
      'function-',
      'firebasefunctions-',
      'firebase-functions-',
      'firebasefunctionsexceptioncode-',
    ];
    for (final prefix in prefixes) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length);
        break;
      }
    }

    value = value.replaceAll(RegExp('-{2,}'), '-');
    value = value.trim();
    if (value.startsWith('-')) {
      value = value.substring(1);
    }
    if (value.endsWith('-')) {
      value = value.substring(0, value.length - 1);
    }

    return value;
  }

  // Validate and use a code
  Future<InvitationCode?> validateAndUseCode({
    required String code,
    required String patientId,
  }) async {
    try {
      // Prefer secure server-side validation to satisfy Firestore rules
      final callable = _functions.httpsCallable('validateAndUseInvitation');
      final result = await callable.call({'code': code});

      final data = _normalizeDynamicMap(result.data);
      final payload = data['invitation'];
      if (payload is Map) {
        return InvitationCode.fromJson(_normalizeDynamicMap(payload));
      }
    } on FirebaseFunctionsException catch (e) {
      // If the function is temporarily unavailable or failing internally,
      // gracefully fall back to a direct Firestore transaction.
      if (_shouldFallbackToFirestore(e)) {
        try {
          final snapshot = await _firestore
              .collection(_collection)
              .where('code', isEqualTo: code)
              .limit(1)
              .get();
          if (snapshot.docs.isEmpty) return null;
          final invitation = InvitationCode.fromJson(snapshot.docs.first.data());
          if (invitation.isUsed) return null;
          if (invitation.expiresAt.isBefore(DateTime.now())) return null;
          final updatedInvitation = invitation.copyWith(
            isUsed: true,
            usedAt: DateTime.now(),
            patientId: patientId,
          );
          await _firestore.collection(_collection).doc(invitation.id).update({
            'is_used': true,
            'used_at': Timestamp.fromDate(updatedInvitation.usedAt!),
            'patient_id': patientId,
          });
          return updatedInvitation;
        } catch (_) {
          // If fallback fails, rethrow original function exception for visibility
          throw Exception('Failed to validate code: ${e.message ?? e.code}');
        }
      }
      // Non-fallbackable errors (e.g., permission issues or invalid-argument)
      throw Exception('Failed to validate code: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to validate code: $e');
    }
    return null;
  }

  // Preview a code without consuming it (for pre-auth verification and prefill)
  Future<InvitationCode?> previewValidCode(String code) async {
    try {
      // Use server-side preview to allow pre-auth checks without broad read rules
      final callable = _functions.httpsCallable('previewInvitationByCode');
      final result = await callable.call({'code': code});
      final data = _normalizeDynamicMap(result.data);
      final payload = data['invitation'];
      if (payload is Map) {
        final inv = InvitationCode.fromJson(_normalizeDynamicMap(payload));
        if (inv.isUsed || inv.expiresAt.isBefore(DateTime.now())) return null;
        return inv;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToFirestore(e)) {
        try {
          final snapshot = await _firestore
              .collection(_collection)
              .where('code', isEqualTo: code)
              .limit(1)
              .get();
          if (snapshot.docs.isEmpty) return null;
          final inv = InvitationCode.fromJson(snapshot.docs.first.data());
          if (inv.isUsed || inv.expiresAt.isBefore(DateTime.now())) return null;
          return inv;
        } catch (_) {
          throw Exception('Failed to preview code: ${e.message ?? e.code}');
        }
      }
      throw Exception('Failed to preview code: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to preview code: $e');
    }
  }

  // Get invitation by code
  Future<InvitationCode?> getInvitationByCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return InvitationCode.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to get invitation: $e');
    }
  }

  // Get invitations sent by therapist
  Future<List<InvitationCode>> getTherapistInvitations(String therapistId) async {
    try {
      // Route through Cloud Function to satisfy security rules reliably
      final callable = _functions.httpsCallable('getTherapistInvitations');
      final result = await callable.call({'therapistId': therapistId});
      final data = _normalizeDynamicMap(result.data);
      final list = <InvitationCode>[];
      final raw = data['invitations'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(InvitationCode.fromJson(_normalizeDynamicMap(item)));
          }
        }
      }
      // Already sorted server-side, but keep stable sort defensively
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToFirestore(e)) {
        try {
          return await _getTherapistInvitationsFromFirestore(therapistId);
        } catch (_) {
          throw Exception('Failed to get therapist invitations: [$e]');
        }
      }
      rethrow;
    } catch (e) {
      throw Exception('Failed to get therapist invitations: $e');
    }
  }

  // Get invitation by patient ID
  Future<InvitationCode?> getInvitationByPatientId(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('patient_id', isEqualTo: patientId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return InvitationCode.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to get invitation by patient: $e');
    }
  }

  // Get all accepted invitations for a patient so they can manage multiple therapists.
  Future<List<InvitationCode>> getAcceptedInvitationsForPatient(String patientId) async {
    try {
      final callable = _functions.httpsCallable('getAcceptedInvitationsForPatient');
      final result = await callable.call({'patientId': patientId});
      final data = _normalizeDynamicMap(result.data);
      final out = <InvitationCode>[];
      final raw = data['invitations'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) out.add(InvitationCode.fromJson(_normalizeDynamicMap(item)));
        }
      }
      out.sort((a, b) {
        final au = a.usedAt;
        final bu = b.usedAt;
        if (au == null && bu == null) return 0;
        if (au == null) return 1;
        if (bu == null) return -1;
        return bu.compareTo(au);
      });
      return out;
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToFirestore(e)) {
        try {
          return await _getPatientAcceptedInvitationsFromFirestore(patientId);
        } catch (_) {
          throw Exception('Failed to get accepted patient invitations: [$e]');
        }
      }
      rethrow;
    } catch (e) {
      throw Exception('Failed to get accepted patient invitations: $e');
    }
  }

  // Get accepted/used invitations for a therapist
  Future<List<InvitationCode>> getAcceptedInvitationsForTherapist(String therapistId) async {
    try {
      final callable = _functions.httpsCallable('getAcceptedInvitationsForTherapist');
      final result = await callable.call({'therapistId': therapistId});
      final data = _normalizeDynamicMap(result.data);
      final out = <InvitationCode>[];
      final raw = data['invitations'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) out.add(InvitationCode.fromJson(_normalizeDynamicMap(item)));
        }
      }
      out.sort((a, b) {
        final au = a.usedAt;
        final bu = b.usedAt;
        if (au == null && bu == null) return 0;
        if (au == null) return 1;
        if (bu == null) return -1;
        return bu.compareTo(au);
      });
      return out;
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToFirestore(e)) {
        try {
          return await _getTherapistInvitationsFromFirestore(therapistId, isUsed: true);
        } catch (_) {
          throw Exception('Failed to get accepted invitations: [$e]');
        }
      }
      rethrow;
    } catch (e) {
      throw Exception('Failed to get accepted invitations: $e');
    }
  }

  // Delete an invitation if it is not used and owned by therapist
  Future<void> deleteInvitation({
    required String invitationId,
    required String therapistId,
  }) async {
    try {
      final callable = _functions.httpsCallable('deleteInvitation');
      await callable.call({'invitationId': invitationId});
    } catch (e) {
      throw Exception('Failed to delete invitation: $e');
    }
  }

  // Fallback helpers
  Future<List<InvitationCode>> _getTherapistInvitationsFromFirestore(
    String therapistId, {
    bool? isUsed,
  }) async {
    // Avoid composite index by querying on a single field and filtering client-side
    final snap = await _firestore
        .collection(_collection)
        .where('therapist_id', isEqualTo: therapistId)
        .get();
    var list = snap.docs.map((d) => InvitationCode.fromJson(d.data())).toList();
    if (isUsed != null) {
      list = list.where((inv) => inv.isUsed == isUsed).toList();
    }
    if (isUsed == true) {
      // Sort by usedAt desc then createdAt desc
      list.sort((a, b) {
        final au = a.usedAt;
        final bu = b.usedAt;
        if (au == null && bu == null) {
          return b.createdAt.compareTo(a.createdAt);
        }
        if (au == null) return 1;
        if (bu == null) return -1;
        final cmp = bu.compareTo(au);
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
    } else {
      // Sort by createdAt desc
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Future<List<InvitationCode>> _getPatientAcceptedInvitationsFromFirestore(
      String patientId) async {
    // Avoid composite index by querying on a single field and filtering client-side
    final snap = await _firestore
        .collection(_collection)
        .where('patient_id', isEqualTo: patientId)
        .get();
    final list = snap.docs
        .map((d) => InvitationCode.fromJson(d.data()))
        .where((inv) => inv.isUsed)
        .toList();
    list.sort((a, b) {
      final au = a.usedAt;
      final bu = b.usedAt;
      if (au == null && bu == null) return b.createdAt.compareTo(a.createdAt);
      if (au == null) return 1;
      if (bu == null) return -1;
      final cmp = bu.compareTo(au);
      return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }
}

class CreateInvitationResult {
  final InvitationCode invitation;
  final bool emailSent;
  const CreateInvitationResult({required this.invitation, required this.emailSent});
}

Map<String, dynamic> _normalizeDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(entry.key, _normalizeDynamicValue(entry.value)),
      ),
    );
  }
  if (value is Map) {
    return value.map<String, dynamic>(
      (key, val) => MapEntry(key.toString(), _normalizeDynamicValue(val)),
    );
  }
  if (value == null) {
    return const {};
  }

  try {
    final jsonString = jsonEncode(value);
    final decoded = jsonDecode(jsonString);
    if (decoded is Map) {
      return decoded.map<String, dynamic>(
        (key, val) => MapEntry(key.toString(), _normalizeDynamicValue(val)),
      );
    }
  } catch (_) {
    // Fall through to empty map if serialization fails
  }

  return const {};
}

dynamic _normalizeDynamicValue(dynamic value) {
  if (value is Map) {
    return _normalizeDynamicMap(value);
  }
  if (value is List) {
    return value.map(_normalizeDynamicValue).toList();
  }
  if (value == null) return null;
  if (value is Timestamp || value is DateTime) return value;
  if (value is num || value is bool || value is String) return value;

  final numeric = int.tryParse(value.toString());
  if (numeric != null) return numeric;

  // Fall back to string to avoid unsupported Int64 accessors on web while
  // keeping a readable representation for logging/debugging.
  return value.toString();
}

DateTime? _extractDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

class InvitationException implements Exception {
  final String message;
  const InvitationException(this.message);

  @override
  String toString() => message;
}
