import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  final String id;
  final String therapistId;
  final String patientId;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final String? lastMessageSenderRole;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int therapistUnreadCount;
  final int patientUnreadCount;

  const ChatConversation({
    required this.id,
    required this.therapistId,
    required this.patientId,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageSenderRole,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    this.therapistUnreadCount = 0,
    this.patientUnreadCount = 0,
  });

  factory ChatConversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatConversation(
      id: doc.id,
      therapistId: data['therapist_id'] ?? '',
      patientId: data['patient_id'] ?? '',
      lastMessageText: data['last_message_text'] as String?,
      lastMessageSenderId: data['last_message_sender_id'] as String?,
      lastMessageSenderRole: data['last_message_sender_role'] as String?,
      lastMessageAt: _timestampToDate(data['last_message_at']),
      createdAt: _timestampToDate(data['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _timestampToDate(data['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      therapistUnreadCount: (data['therapist_unread_count'] ?? 0) as int,
      patientUnreadCount: (data['patient_unread_count'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'therapist_id': therapistId,
        'patient_id': patientId,
        'last_message_text': lastMessageText,
        'last_message_sender_id': lastMessageSenderId,
        'last_message_sender_role': lastMessageSenderRole,
        'last_message_at': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'therapist_unread_count': therapistUnreadCount,
        'patient_unread_count': patientUnreadCount,
      };

  ChatConversation copyWith({
    String? id,
    String? therapistId,
    String? patientId,
    String? lastMessageText,
    String? lastMessageSenderId,
    String? lastMessageSenderRole,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? therapistUnreadCount,
    int? patientUnreadCount,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      therapistId: therapistId ?? this.therapistId,
      patientId: patientId ?? this.patientId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderRole: lastMessageSenderRole ?? this.lastMessageSenderRole,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      therapistUnreadCount: therapistUnreadCount ?? this.therapistUnreadCount,
      patientUnreadCount: patientUnreadCount ?? this.patientUnreadCount,
    );
  }

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}