import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String senderRole;
  final String text;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.senderRole,
    required this.text,
    required this.sentAt,
  });

  bool get isFromTherapist => senderRole == 'therapist';

  factory ChatMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String conversationId,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      conversationId: conversationId,
      senderId: data['sender_id'] ?? '',
      receiverId: data['receiver_id'] ?? '',
      senderRole: data['sender_role'] ?? '',
      text: data['text'] ?? '',
      sentAt: _timestampToDate(data['sent_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_role': senderRole,
        'text': text,
        'sent_at': Timestamp.fromDate(sentAt),
      };

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}