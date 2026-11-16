import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/uploader_service.dart';
import './models/chat_session_model.dart';
import './models/chat_message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.read(apiClientProvider),
    ref.read(uploaderServiceProvider),
  );
});

class ChatRepository {
  final ApiClient _api;
  final UploaderService _uploader;

  ChatRepository(this._api, this._uploader);

  // ============================================================
  // 1. FETCH INBOX SESSIONS
  // GET /api/chats/sessions
  // ============================================================
  Future<List<ChatSessionModel>> fetchSessions() async {
    final response = await _api.dio.get('/chats/sessions');

    return (response.data as List)
        .map(
          (json) =>
              ChatSessionModel.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  // ============================================================
  // 2. FETCH MESSAGES FOR A SESSION
  // GET /api/chats/sessions/:sessionId/messages
  // ============================================================
  Future<List<ChatMessageModel>> fetchMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    // Prevent 404 network errors when opening a brand new admin chat
    if (sessionId == 'new_admin') {
      return [];
    }

    final response = await _api.dio.get(
      '/chats/sessions/$sessionId/messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    return (response.data as List)
        .map(
          (json) =>
              ChatMessageModel.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  // ============================================================
  // 3. INITIATE OR RESUME A CHAT
  // POST /api/chats/sessions/initiate
  // ============================================================
  Future<ChatSessionModel> initiateChat(String partnerId) async {
    final response = await _api.dio.post(
      '/chats/sessions/initiate',
      data: {'partnerId': partnerId},
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    // Ensure partnerId is always populated even if backend returns raw DB columns
    if (data['partnerId'] == null || data['partnerId'].toString().isEmpty) {
      data['partnerId'] = partnerId;
    }

    return ChatSessionModel.fromJson(data);
  }

  // ============================================================
  // 4. SEND A CHAT MESSAGE (TEXT OR IMAGE)
  // POST /api/chats/messages
  // Returns both the resolved sessionId and the created ChatMessageModel
  // ============================================================
  Future<({String sessionId, ChatMessageModel message})> sendMessage({
    required String sessionId,
    String? partnerId,
    String? text,
    String? imageUrl,
  }) async {
    final response = await _api.dio.post(
      '/chats/messages',
      data: {
        'sessionId': sessionId,
        if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final resolvedSessionId = data['sessionId']?.toString() ?? sessionId;
    final messageJson = Map<String, dynamic>.from(data['message'] as Map);

    return (
      sessionId: resolvedSessionId,
      message: ChatMessageModel.fromJson(messageJson),
    );
  }

  // ============================================================
  // 5. UPLOAD CHAT IMAGE
  // Delegates compression and MinIO PUT to UploaderService
  // ============================================================
  Future<String> uploadChatImage(File file, {String? sessionId}) async {
    return await _uploader.uploadFileDirectly(
      file: file,
      endpoint: '/chats/upload/presigned-url',
      payloadData: {
        // Safe check prevents sending dummy IDs to MinIO/Backend
        if (sessionId != null && !sessionId.startsWith('new_'))
          'sessionId': sessionId,
      },
      imageContext: 'chats',
      isGetRequest: true, // Chat routes use GET for presigned URLs
    );
  }
}
