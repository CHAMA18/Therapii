import 'package:cloud_firestore/cloud_firestore.dart';

class Therapist {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String specialization;
  final String bio;
  final double rating;
  final int reviewCount;
  final double hourlyRate;
  final List<String> languages;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;
  final bool isAvailable;

  Therapist({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.specialization,
    required this.bio,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.hourlyRate,
    this.languages = const [],
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'specialization': specialization,
        'bio': bio,
        'rating': rating,
        'review_count': reviewCount,
        'hourly_rate': hourlyRate,
        'languages': languages,
        'profile_image_url': profileImageUrl,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'is_verified': isVerified,
        'is_available': isAvailable,
      };

  static Therapist fromJson(Map<String, dynamic> json) => Therapist(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? json['userId'] ?? '',
        firstName: json['first_name'] ?? json['firstName'] ?? '',
        lastName: json['last_name'] ?? json['lastName'] ?? '',
        specialization: json['specialization'] ?? json['speciality'] ?? '',
        bio: json['bio'] ?? json['biography'] ?? '',
        rating: (json['rating'] ?? 0.0).toDouble(),
        reviewCount: json['review_count'] ?? 0,
        hourlyRate: (json['hourly_rate'] ?? 0.0).toDouble(),
        languages: List<String>.from(json['languages'] ?? []),
        profileImageUrl: json['profile_image_url'],
        createdAt: json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : DateTime.now(),
        isVerified: json['is_verified'] ?? false,
        isAvailable: json['is_available'] ?? true,
      );

  Therapist copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? specialization,
    String? bio,
    double? rating,
    int? reviewCount,
    double? hourlyRate,
    List<String>? languages,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    bool? isAvailable,
  }) =>
      Therapist(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        specialization: specialization ?? this.specialization,
        bio: bio ?? this.bio,
        rating: rating ?? this.rating,
        reviewCount: reviewCount ?? this.reviewCount,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        languages: languages ?? this.languages,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isVerified: isVerified ?? this.isVerified,
        isAvailable: isAvailable ?? this.isAvailable,
      );

  String get fullName => '$firstName $lastName';
}