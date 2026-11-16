class ChatMessageModel {
  final String id;
  final String chatSessionId;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final bool isRead;
  final String createdAt;

  // Required for Optimistic UI Updates & Error Handling
  final bool isSending;
  final bool isFailed;

  const ChatMessageModel({
    required this.id,
    required this.chatSessionId,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.isRead,
    required this.createdAt,
    this.isSending = false, // Defaults to false for confirmed backend messages
    this.isFailed = false, // Defaults to false
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawText = json['text']?.toString() ?? json['content']?.toString();
    final rawImage =
        json['image_url']?.toString() ?? json['imageUrl']?.toString();

    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      chatSessionId:
          json['chat_session_id']?.toString() ??
          json['chatSessionId']?.toString() ??
          '',
      senderId:
          json['sender_id']?.toString() ?? json['senderId']?.toString() ?? '',
      text: (rawText != null && rawText.isNotEmpty) ? rawText : null,
      imageUrl: (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      isRead: _parseBool(json['is_read'] ?? json['isRead']),
      createdAt:
          json['created_at']?.toString() ??
          json['createdAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      isSending: _parseBool(json['isSending']),
      isFailed: _parseBool(json['isFailed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_session_id': chatSessionId,
      'sender_id': senderId,
      'text': text,
      'image_url': imageUrl,
      'is_read': isRead,
      'created_at': createdAt,
      'isSending': isSending,
      'isFailed': isFailed,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? chatSessionId,
    String? senderId,
    String? text,
    String? imageUrl,
    bool? isRead,
    String? createdAt,
    bool? isSending,
    bool? isFailed,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      chatSessionId: chatSessionId ?? this.chatSessionId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      isSending: isSending ?? this.isSending,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }
}
