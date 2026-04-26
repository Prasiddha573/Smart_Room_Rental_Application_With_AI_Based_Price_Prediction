import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio, file }

class ChatMessage {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String message;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final bool isDeleted;

  ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    required this.isDeleted,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'messageId': messageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'isDeleted': isDeleted,
    };
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse MessageType from string
    MessageType parseMessageType(String typeString) {
      switch (typeString.toLowerCase()) {
        case 'image':
          return MessageType.image;
        case 'video':
          return MessageType.video;
        case 'audio':
          return MessageType.audio;
        case 'file':
          return MessageType.file;
        default:
          return MessageType.text;
      }
    }

    return ChatMessage(
      messageId: data['messageId']?.toString() ?? doc.id,
      conversationId: data['conversationId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      receiverId: data['receiverId']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      type: parseMessageType(data['type']?.toString() ?? 'text'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  // Helper method to convert to map (optional, for other uses)
  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type.toString().split('.').last,
      'timestamp': timestamp,
      'isRead': isRead,
      'isDeleted': isDeleted,
    };
  }

  // Copy with method for easy updates
  ChatMessage copyWith({
    String? messageId,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? message,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    bool? isDeleted,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}