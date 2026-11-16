import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/socket/socket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message_model.dart';

final chatMessagesProvider = AsyncNotifierProvider.family
    .autoDispose<ChatMessagesNotifier, List<ChatMessageModel>, String>(() {
      return ChatMessagesNotifier();
    });

class ChatMessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<ChatMessageModel>, String> {
  late SocketService _socket;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final int _limit = 50;

  @override
  Future<List<ChatMessageModel>> build(String arg) async {
    _socket = ref.watch(socketServiceProvider);
    _hasMore = true;
    _isLoadingMore = false;

    // Setup socket listeners for real-time events
    _socket.listen('receive_message', _onReceiveMessage);
    _socket.listen('message_confirmed', _onMessageConfirmed);
    _socket.listen('messages_read_by_recipient', _onMessagesReadByRecipient);
    _socket.listen('read_status_synced', _onReadStatusSynced);

    // ✅ FIX: Pass the exact callback functions so we don't wipe ChatSessionsNotifier's listeners
    ref.onDispose(() {
      _socket.stopListening('receive_message', _onReceiveMessage);
      _socket.stopListening('message_confirmed', _onMessageConfirmed);
      _socket.stopListening(
        'messages_read_by_recipient',
        _onMessagesReadByRecipient,
      );
      _socket.stopListening('read_status_synced', _onReadStatusSynced);
    });

    return _fetchMessages(offset: 0);
  }

  Future<List<ChatMessageModel>> _fetchMessages({required int offset}) async {
    // ✅ FIX: Do not wrap in `throw AsyncValue.error(e, st)`—AsyncNotifier automatically catches and wraps exceptions
    final messages = await ref
        .read(chatRepositoryProvider)
        .fetchMessages(
          arg, // sessionId passed as 'arg'
          limit: _limit,
          offset: offset,
        );

    if (messages.length < _limit) {
      _hasMore = false;
    }
    return messages;
  }

  // ==========================================================
  // PAGINATION (LOAD OLDER MESSAGES)
  // ==========================================================
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || !state.hasValue || arg == 'new_admin') {
      return;
    }

    _isLoadingMore = true;

    try {
      final currentList = state.value!;
      // ✅ FIX: Calculate exact offset from confirmed messages so newly sent/received messages don't shift pagination
      final confirmedCount = currentList
          .where((m) => !m.id.startsWith('temp_'))
          .length;

      final olderMessages = await _fetchMessages(offset: confirmedCount);

      if (olderMessages.isNotEmpty && state.hasValue) {
        final existingIds = state.value!.map((m) => m.id).toSet();
        final uniqueOlder = olderMessages
            .where((m) => !existingIds.contains(m.id))
            .toList();

        state = AsyncValue.data([...state.value!, ...uniqueOlder]);
      }
    } catch (e) {
      log('LoadMore Messages Error: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  // ==========================================================
  // SEND MESSAGE (OPTIMISTIC UI + HTTP POST)
  // Returns the real sessionId (useful when upgrading 'new_admin')
  // ==========================================================
  Future<String?> sendMessage({
    required String text,
    required String receiverId,
    String? imageUrl,
  }) async {
    final trimmedText = text.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (trimmedText.isEmpty && !hasImage) {
      return null;
    }

    final currentUserId =
        ref.read(currentUserProvider)?['id']?.toString() ?? '';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Create a temporary optimistic message
    final tempMessage = ChatMessageModel(
      id: tempId,
      chatSessionId: arg,
      senderId: currentUserId,
      text: trimmedText.isNotEmpty ? trimmedText : null,
      imageUrl: imageUrl,
      isRead: false,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      isSending: true,
      isFailed: false,
    );

    // 2. Instantly prepend to UI
    if (state.hasValue) {
      state = AsyncValue.data([tempMessage, ...state.value!]);
    }

    try {
      // 3. Delegate to ChatRepository.sendMessage (POST /chats/messages)
      // Note: Backend POST /chats/messages already saves to DB and emits 'receive_message' via Socket.IO
      final result = await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            sessionId: arg,
            partnerId: receiverId,
            text: trimmedText,
            imageUrl: imageUrl,
          );

      final realSessionId = result.sessionId;
      final newMessage = result.message;

      // 4. Confirm the message in local state (Swap tempId with real UUID)
      if (state.hasValue) {
        final currentMessages = state.value!;

        // Check if Socket 'receive_message' already swapped/inserted this message while HTTP was in flight
        final alreadyConfirmedBySocket = currentMessages.any(
          (m) => m.id == newMessage.id,
        );

        if (alreadyConfirmedBySocket) {
          // Remove the leftover temp message if socket already inserted the real one
          final cleanedList = currentMessages
              .where((m) => m.id != tempId)
              .toList();
          state = AsyncValue.data(cleanedList);
        } else {
          final updatedList = currentMessages.map((msg) {
            return msg.id == tempId ? newMessage : msg;
          }).toList();
          state = AsyncValue.data(updatedList);
        }
      }

      return realSessionId;
    } catch (e) {
      log('❌ Failed to send message: $e');

      // Mark optimistic bubble as failed in UI
      if (state.hasValue) {
        final updatedList = state.value!.map((msg) {
          if (msg.id == tempId) {
            return msg.copyWith(isFailed: true, isSending: false);
          }
          return msg;
        }).toList();
        state = AsyncValue.data(updatedList);
      }
      return null;
    }
  }

  // ==========================================================
  // MARK INCOMING MESSAGES AS READ
  // ==========================================================
  void markAsRead(String senderId) {
    if (arg == 'new_admin' || senderId.isEmpty) return;

    try {
      _socket.emit('mark_messages_read', {
        'chatSessionId': arg,
        'senderId': senderId,
      });

      if (state.hasValue) {
        final currentMessages = state.value!;
        final hasUnreadFromPartner = currentMessages.any(
          (msg) => msg.senderId == senderId && !msg.isRead,
        );

        if (!hasUnreadFromPartner) return;

        final updatedList = currentMessages.map((msg) {
          if (msg.senderId == senderId && !msg.isRead) {
            return msg.copyWith(isRead: true);
          }
          return msg;
        }).toList();

        state = AsyncValue.data(updatedList);
      }
    } catch (_) {}
  }

  // ==========================================================
  // SOCKET: RECEIVE MESSAGE (DEDUPLICATED & RACE-SAFE)
  // ==========================================================
  void _onReceiveMessage(dynamic payload) {
    if (!state.hasValue) return;
    try {
      final msg = ChatMessageModel.fromJson(
        Map<String, dynamic>.from(payload as Map),
      );

      // Ensure the message belongs to this specific chat room
      if (msg.chatSessionId != arg && arg != 'new_admin') return;

      final currentMessages = state.value!;

      // 1. Ignore if already present by real UUID
      if (currentMessages.any((m) => m.id == msg.id)) return;

      // 2. Race Condition Check: Did Socket beat the HTTP response?
      final tempMessageIndex = currentMessages.indexWhere(
        (m) =>
            (m.isSending == true || m.id.startsWith('temp_')) &&
            m.senderId == msg.senderId &&
            (m.text ?? '').trim() == (msg.text ?? '').trim() &&
            (m.imageUrl ?? '') == (msg.imageUrl ?? ''),
      );

      if (tempMessageIndex != -1) {
        final updatedList = List<ChatMessageModel>.from(currentMessages);
        updatedList[tempMessageIndex] = msg;
        state = AsyncValue.data(updatedList);
      } else {
        state = AsyncValue.data([msg, ...currentMessages]);
      }
    } catch (_) {}
  }

  void _onMessageConfirmed(dynamic payload) {
    if (!state.hasValue) return;
    try {
      final data = Map<String, dynamic>.from(payload as Map);
      final rawMsg = data['message'] ?? data;
      final msg = ChatMessageModel.fromJson(
        Map<String, dynamic>.from(rawMsg as Map),
      );

      if (msg.chatSessionId == arg) {
        final currentMessages = state.value!;
        if (!currentMessages.any((m) => m.id == msg.id)) {
          state = AsyncValue.data([msg, ...currentMessages]);
        }
      }
    } catch (_) {}
  }

  // ==========================================================
  // SOCKET: READ RECEIPTS
  // ==========================================================
  void _onMessagesReadByRecipient(dynamic payload) {
    if (!state.hasValue) return;
    try {
      final data = Map<String, dynamic>.from(payload as Map);
      final sessionId =
          data['chatSessionId']?.toString() ??
          data['chat_session_id']?.toString();

      // If sessionId is provided in payload, verify it matches this room
      if (sessionId != null && sessionId != arg) return;

      final currentUserId =
          ref.read(currentUserProvider)?['id']?.toString() ?? '';

      final updatedList = state.value!.map((m) {
        if (m.senderId == currentUserId && !m.isRead) {
          return m.copyWith(isRead: true);
        }
        return m;
      }).toList();

      state = AsyncValue.data(updatedList);
    } catch (_) {}
  }

  void _onReadStatusSynced(dynamic payload) {
    if (!state.hasValue) return;
    try {
      final data = Map<String, dynamic>.from(payload as Map);
      final partnerId = data['partnerId']?.toString();

      final updatedList = state.value!.map((m) {
        if ((partnerId == null || m.senderId == partnerId) && !m.isRead) {
          return m.copyWith(isRead: true);
        }
        return m;
      }).toList();

      state = AsyncValue.data(updatedList);
    } catch (_) {}
  }
}
