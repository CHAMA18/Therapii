import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateOrFallback(dynamic value, DateTime fallback) {
  final parsed = _parseDate(value);
  return parsed ?? fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  if (value is Map) {
    final seconds = _parseInt(value['seconds'] ?? value['_seconds']);
    final nanos = _parseInt(value['nanoseconds'] ?? value['_nanoseconds']) ?? 0;
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + nanos ~/ 1000000,
      );
    }
  }
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  final valueString = value.toString();
  return int.tryParse(valueString);
}

class InvitationCode {
  final String id;
  final String code;
  final String therapistId;
  final String patientEmail;
  final String patientFirstName;
  final String patientLastName;
  final String? patientId;
  final bool isUsed;
  final DateTime createdAt;
  final DateTime? usedAt;
  final DateTime expiresAt;

  const InvitationCode({
    required this.id,
    required this.code,
    required this.therapistId,
    required this.patientEmail,
    required this.patientFirstName,
    this.patientLastName = '',
    this.patientId,
    this.isUsed = false,
    required this.createdAt,
    this.usedAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'therapist_id': therapistId,
        'patient_email': patientEmail,
        'patient_first_name': patientFirstName,
        'patient_last_name': patientLastName,
        'patient_id': patientId,
        'is_used': isUsed,
        'created_at': Timestamp.fromDate(createdAt),
        'used_at': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
        'expires_at': Timestamp.fromDate(expiresAt),
      };

  static InvitationCode fromJson(Map<String, dynamic> json) => InvitationCode(
        id: json['id'] ?? json['invitationId'] ?? '',
        code: json['code'] ?? json['invitation_code'] ?? '',
        therapistId:
            json['therapist_id'] ?? json['therapistId'] ?? json['therapistID'] ?? '',
        patientEmail:
            json['patient_email'] ?? json['patientEmail'] ?? json['email'] ?? '',
        patientFirstName:
            json['patient_first_name'] ?? json['patientFirstName'] ?? '',
        patientLastName:
            json['patient_last_name'] ?? json['patientLastName'] ?? '',
        patientId: json['patient_id'] ?? json['patientId'],
        isUsed: json['is_used'] ?? json['isUsed'] ?? false,
        createdAt: _parseDateOrFallback(
          json['created_at'] ?? json['createdAt'],
          DateTime.now(),
        ),
        usedAt: _parseDate(json['used_at'] ?? json['usedAt']),
        expiresAt: _parseDateOrFallback(
          json['expires_at'] ?? json['expiresAt'],
          DateTime.now().add(const Duration(hours: 48)),
        ),
      );

  InvitationCode copyWith({
    String? id,
    String? code,
    String? therapistId,
    String? patientEmail,
    String? patientFirstName,
    String? patientLastName,
    String? patientId,
    bool? isUsed,
    DateTime? createdAt,
    DateTime? usedAt,
    DateTime? expiresAt,
  }) =>
      InvitationCode(
        id: id ?? this.id,
        code: code ?? this.code,
        therapistId: therapistId ?? this.therapistId,
        patientEmail: patientEmail ?? this.patientEmail,
        patientFirstName: patientFirstName ?? this.patientFirstName,
        patientLastName: patientLastName ?? this.patientLastName,
        patientId: patientId ?? this.patientId,
        isUsed: isUsed ?? this.isUsed,
        createdAt: createdAt ?? this.createdAt,
        usedAt: usedAt ?? this.usedAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  String get patientFullName {
    if (patientLastName.isEmpty) return patientFirstName;
    if (patientFirstName.isEmpty) return patientLastName;
    return '$patientFirstName $patientLastName';
  }
}
