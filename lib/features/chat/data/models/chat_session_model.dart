class ChatSessionModel {
  final String id;
  final String partnerId;
  final String? partnerName;
  final String? partnerAvatar;
  final String? lastMessage;
  final String updatedAt;
  final int unreadCount;
  final bool isOnline;
  final bool isTyping;
  final String? lastSeen;

  // ✅ NEW: Direct backend flag to easily identify Support/Admin accounts
  final bool isAdmin;

  const ChatSessionModel({
    required this.id,
    required this.partnerId,
    this.partnerName,
    this.partnerAvatar,
    this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isTyping = false,
    this.lastSeen,
    this.isAdmin = false, // Defaults to false for standard users
  });

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    return ChatSessionModel(
      id: json['id']?.toString() ?? '',
      partnerId: json['partnerId']?.toString() ?? '',
      partnerName: json['partnerName']?.toString(),
      partnerAvatar: json['partnerAvatar']?.toString(),
      lastMessage: json['lastMessage']?.toString(),
      updatedAt:
          json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      unreadCount: json['unreadCount'] as int? ?? 0,
      isOnline: json['isOnline'] as bool? ?? false,
      isTyping: json['isTyping'] as bool? ?? false,
      lastSeen: json['lastSeen']?.toString(),

      // ✅ Parses the boolean from the backend.
      // We also handle cases where the backend might send it as 1/0 or a string.
      isAdmin: _parseBool(json['isAdmin']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerAvatar': partnerAvatar,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt,
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'isTyping': isTyping,
      'lastSeen': lastSeen,
      'isAdmin': isAdmin, // ✅ Send back to JSON
    };
  }

  ChatSessionModel copyWith({
    String? id,
    String? partnerId,
    String? partnerName,
    String? partnerAvatar,
    String? lastMessage,
    String? updatedAt,
    int? unreadCount,
    bool? isOnline,
    bool? isTyping,
    String? lastSeen,
    bool? isAdmin, // ✅ Allow copying the flag
  }) {
    return ChatSessionModel(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isTyping: isTyping ?? this.isTyping,
      lastSeen: lastSeen ?? this.lastSeen,
      isAdmin: isAdmin ?? this.isAdmin, // ✅ Maintain state during updates
    );
  }

  // Helper to safely parse boolean values from various backend formats
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }
}
