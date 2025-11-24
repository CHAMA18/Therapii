import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String? therapistId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTherapist;
  final Map<String, dynamic>? patientOnboardingData;
  final bool patientOnboardingCompleted;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.avatarUrl,
    this.therapistId,
    required this.createdAt,
    required this.updatedAt,
    this.isTherapist = false,
    this.patientOnboardingData,
    this.patientOnboardingCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'avatar_url': avatarUrl,
        'therapist_id': therapistId,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'is_therapist': isTherapist,
        'patient_onboarding_data': patientOnboardingData,
        'patient_onboarding_completed': patientOnboardingCompleted,
      };

  static User fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? '',
        email: json['email'] ?? '',
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        phoneNumber: json['phone_number'],
        avatarUrl: json['avatar_url'],
        therapistId: json['therapist_id'],
        createdAt: json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : DateTime.now(),
        isTherapist: json['is_therapist'] ?? false,
        patientOnboardingData: json['patient_onboarding_data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['patient_onboarding_data'] as Map)
            : null,
        patientOnboardingCompleted: json['patient_onboarding_completed'] ?? false,
      );

  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? avatarUrl,
    String? therapistId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isTherapist,
    Map<String, dynamic>? patientOnboardingData,
    bool? patientOnboardingCompleted,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        therapistId: therapistId ?? this.therapistId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isTherapist: isTherapist ?? this.isTherapist,
        patientOnboardingData: patientOnboardingData ?? this.patientOnboardingData,
        patientOnboardingCompleted: patientOnboardingCompleted ?? this.patientOnboardingCompleted,
      );

  String get fullName => '$firstName $lastName';
}
