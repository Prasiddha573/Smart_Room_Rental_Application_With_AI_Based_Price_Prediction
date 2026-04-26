// lib/chat/models/conversation.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String conversationId;
  final String user1Id;
  final String user2Id;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;
  final Map<String, bool> isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.conversationId,
    required this.user1Id,
    required this.user2Id,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      conversationId: doc.id, // Use document ID as conversationId
      user1Id: data['user1Id']?.toString() ?? '',
      user2Id: data['user2Id']?.toString() ?? '',
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSenderId: data['lastMessageSenderId']?.toString() ?? '',
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      isFavorite: Map<String, bool>.from(data['isFavorite'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}