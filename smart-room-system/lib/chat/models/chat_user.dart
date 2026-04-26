import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.sessionId,
    required this.profilePath,
    required this.createdAt,
    this.lastSeen,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String sessionId;
  final String profilePath;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isOnline;

  // Factory method to create ChatUser from Firestore data
  factory ChatUser.fromFirestore(Map<String, dynamic> data) {
    print('📄 ChatUser.fromFirestore data: $data');

    // Extract name from multiple possible field names
    final name = _extractName(data);

    // Extract sessionId/UID from multiple possible field names
    final sessionId = _extractSessionId(data);

    // Extract ID - prioritize sessionId, then fallback
    final id = sessionId.isNotEmpty
        ? sessionId
        : (data['id']?.toString() ?? '');

    // Ensure we always have an ID
    final finalId = id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch.toString();

    return ChatUser(
      id: finalId,
      name: name.isNotEmpty ? name : 'Room Owner',
      email: data['Email']?.toString() ?? data['email']?.toString() ?? '',
      phone: data['Phone']?.toString() ?? data['phone']?.toString() ?? '',
      sessionId: sessionId,
      profilePath: _extractProfilePath(data),
      createdAt: _extractDateTime(data['createdAt']) ?? DateTime.now(), // FIX: Provide default
      lastSeen: _extractDateTime(data['lastSeen']), // This can be null
      isOnline: data['isOnline'] ?? data['online'] ?? false,
    );
  }

  // Helper method to extract name
  static String _extractName(Map<String, dynamic> data) {
    // Try multiple field names in order of priority
    final List<String> possibleNameFields = [
      'Name',
      'name',
      'displayName',
      'fullName',
      'username',
      'userName',
    ];

    for (final field in possibleNameFields) {
      if (data[field] != null && data[field].toString().isNotEmpty) {
        return data[field].toString().trim();
      }
    }

    return '';
  }

  // Helper method to extract sessionId/UID
  static String _extractSessionId(Map<String, dynamic> data) {
    final List<String> possibleIdFields = [
      'SessionId',
      'sessionId',
      'uid',
      'userId',
      'firebaseUid',
      'UID',
    ];

    for (final field in possibleIdFields) {
      if (data[field] != null && data[field].toString().isNotEmpty) {
        return data[field].toString().trim();
      }
    }

    return '';
  }

  // Helper method to extract profile path
  static String _extractProfilePath(Map<String, dynamic> data) {
    final List<String> possibleImageFields = [
      'Path',
      'path',
      'profilePath',
      'profileUrl',
      'imageUrl',
      'photoURL',
      'avatar',
      'profileImage',
    ];

    for (final field in possibleImageFields) {
      if (data[field] != null && data[field].toString().isNotEmpty) {
        return data[field].toString().trim();
      }
    }

    return '';
  }

  // Helper method to extract DateTime from various formats
  static DateTime? _extractDateTime(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is DateTime) {
      return timestamp;
    }

    if (timestamp is String) {
      try {
        // Try parsing ISO string
        return DateTime.parse(timestamp);
      } catch (e) {
        // Try parsing milliseconds
        final millis = int.tryParse(timestamp);
        if (millis != null) {
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
    }

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    return null;
  }

  // Factory method to create a temporary user (for room owners not in User collection)
  factory ChatUser.createTemporary({
    required String userId,
    String name = 'Room Owner',
    String email = '',
    String phone = '',
    String profilePath = '',
  }) {
    return ChatUser(
      id: userId,
      name: name,
      email: email,
      phone: phone,
      sessionId: userId,
      profilePath: profilePath,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: false,
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'Name': name,
      'Email': email,
      'Phone': phone,
      'SessionId': sessionId,
      'Path': profilePath,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'isOnline': isOnline,
    };
  }

  // Convert to simplified map for UI display
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'sessionId': sessionId,
      'profilePath': profilePath,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'isOnline': isOnline,
    };
  }

  // Create a copy with updated values
  ChatUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? sessionId,
    String? profilePath,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
  }) {
    return ChatUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      sessionId: sessionId ?? this.sessionId,
      profilePath: profilePath ?? this.profilePath,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  // Check if user is valid (has required fields)
  bool get isValid => id.isNotEmpty && name.isNotEmpty && sessionId.isNotEmpty;

  // Get initials for avatar
  String get initials {
    if (name.isEmpty) return '?';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    } else {
      return name[0].toUpperCase();
    }
  }

  // Check if user was active recently (within last 5 minutes)
  bool get isRecentlyActive {
    if (lastSeen == null) return false;

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);
    return difference.inMinutes <= 5;
  }

  // Format last seen time for display
  String get formattedLastSeen {
    if (lastSeen == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${difference.inDays ~/ 7}w ago';
  }

  @override
  String toString() {
    return 'ChatUser{id: $id, name: $name, email: $email, sessionId: $sessionId, isOnline: $isOnline}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ChatUser &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              sessionId == other.sessionId;

  @override
  int get hashCode => id.hashCode ^ sessionId.hashCode;
}