import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/chat_repository.dart';
import '../../data/models/chat_session_model.dart';
import '../../providers/active_chat_provider.dart';
import '../../providers/chat_messages_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String partnerId;
  final String? partnerName;
  final String? partnerAvatar;
  final String? jobId;
  final String? jobTitle;

  const ChatDetailScreen({
    super.key,
    required this.sessionId,
    required this.partnerId,
    this.partnerName,
    this.partnerAvatar,
    this.jobId,
    this.jobTitle,
  });

  /// Convenience factory when constructing from a [ChatSessionModel] in GoRouter
  factory ChatDetailScreen.fromSession({
    Key? key,
    required ChatSessionModel session,
    String? jobId,
    String? jobTitle,
  }) {
    return ChatDetailScreen(
      key: key,
      sessionId: session.id,
      partnerId: session.partnerId,
      partnerName: session.partnerName,
      partnerAvatar: session.partnerAvatar,
      jobId: jobId,
      jobTitle: jobTitle,
    );
  }

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // Cached references for safe cleanup in dispose() without calling ref.read()
  SocketService? _socket;
  StateController<String?>? _activeSessionNotifier;

  // Typing debounce timer
  Timer? _typingDebounce;
  bool _isCurrentlyTyping = false;

  // Track the active session ID (allows upgrading from 'new_admin' to a real UUID)
  late String _currentSessionId;
  bool _isUploading = false;

  // Real-time State Variables
  bool _partnerIsTyping = false;
  bool _partnerIsOnline = false;
  DateTime? _partnerLastSeen;

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;

    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _activeSessionNotifier = ref.read(activeChatSessionProvider.notifier);
      _activeSessionNotifier?.state = _currentSessionId;

      if (_currentSessionId != 'new_admin') {
        ref
            .read(chatMessagesProvider(_currentSessionId).notifier)
            .markAsRead(widget.partnerId);
      }

      _socket = ref.read(socketServiceProvider);
      _socket?.listen('user_typing', _onPartnerTyping);
      _socket?.listen('user_stopped_typing', _onPartnerStoppedTyping);
      _socket?.listen('user_status_changed', _onUserStatusChanged);
      _socket?.listen('user_presence', _onUserStatusChanged);

      if (widget.partnerId.isNotEmpty && widget.partnerId != 'admin') {
        _socket?.emit('check_presence', {'userId': widget.partnerId});
      }
    });
  }

  // ==========================================
  // REAL-TIME SOCKET HANDLERS
  // ==========================================

  void _onPartnerTyping(dynamic payload) {
    if (!mounted) return;
    try {
      final data = Map<String, dynamic>.from(payload as Map);
      if (data['userId']?.toString() == widget.partnerId) {
        setState(() => _partnerIsTyping = true);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _onPartnerStoppedTyping(dynamic payload) {
    if (!mounted) return;
    try {
      final data = Map<String, dynamic>.from(payload as Map);
      if (data['userId']?.toString() == widget.partnerId) {
        setState(() => _partnerIsTyping = false);
      }
    } catch (_) {}
  }

  void _onUserStatusChanged(dynamic payload) {
    if (!mounted) return;
    try {
      final data = Map<String, dynamic>.from(payload as Map);
      if (data['userId']?.toString() == widget.partnerId) {
        setState(() {
          _partnerIsOnline = data['isOnline'] as bool? ?? false;
          final lastSeenStr = data['lastSeen']?.toString();
          if (lastSeenStr != null && lastSeenStr.isNotEmpty) {
            _partnerLastSeen = DateTime.tryParse(lastSeenStr);
          }
        });
      }
    } catch (_) {}
  }

  void _handleUserTyping() {
    if (widget.partnerId.isEmpty) return;

    if (!_isCurrentlyTyping) {
      _isCurrentlyTyping = true;
      _socket?.emit('typing', {'receiverId': widget.partnerId});
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _isCurrentlyTyping = false;
      _socket?.emit('stop_typing', {'receiverId': widget.partnerId});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      if (widget.partnerId.isNotEmpty && widget.partnerId != 'admin') {
        _socket?.emit('check_presence', {'userId': widget.partnerId});
      }
      if (_currentSessionId != 'new_admin') {
        ref
            .read(chatMessagesProvider(_currentSessionId).notifier)
            .markAsRead(widget.partnerId);
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // ✅ FIXED: Restored subtraction operator `- 200`
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMessagesProvider(_currentSessionId).notifier).loadMore();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ==========================================
  // IMAGE UPLOAD & SENDING
  // ==========================================

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final repo = ref.read(chatRepositoryProvider);
      final imageUrl = await repo.uploadChatImage(
        File(image.path),
        sessionId: _currentSessionId,
      );

      final newSessionId = await ref
          .read(chatMessagesProvider(_currentSessionId).notifier)
          .sendMessage(
            text: '',
            receiverId: widget.partnerId,
            imageUrl: imageUrl,
          );

      _handleSessionUpgrade(newSessionId);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка загрузки фото: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ✅ SILENTLY UPGRADE THE ROUTE IF WE JUST CREATED A SUPPORT SESSION
  void _handleSessionUpgrade(String? returnedSessionId) {
    if (_currentSessionId == 'new_admin' &&
        returnedSessionId != null &&
        returnedSessionId.isNotEmpty &&
        returnedSessionId != 'new_admin') {
      setState(() {
        _currentSessionId = returnedSessionId;
      });

      // Update global active chat pointer
      _activeSessionNotifier?.state = _currentSessionId;

      // ✅ FIXED: Use AppRoutes.chatDetail with query parameters matching app_router.dart
      final upgradedUri = Uri(
        path: '${AppRoutes.chatDetail}/$_currentSessionId',
        queryParameters: {
          'partnerId': widget.partnerId,
          if (widget.partnerName != null) 'partnerName': widget.partnerName!,
          if (widget.partnerAvatar != null)
            'partnerAvatar': widget.partnerAvatar!,
        },
      );
      context.replace(upgradedUri.toString());
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    String dateText;
    if (msgDay == today) {
      dateText = 'Сегодня';
    } else if (msgDay == yesterday) {
      dateText = 'Вчера';
    } else {
      dateText = DateFormat('d MMMM', 'ru').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateText,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    final isAdmin =
        widget.partnerId == 'admin' ||
        (widget.partnerName?.toLowerCase().contains('поддержк') ?? false);

    String statusText = _partnerIsTyping
        ? 'Печатает...'
        : (isAdmin ? 'Оператор онлайн' : 'Не в сети');

    Color dotColor = _partnerIsTyping
        ? Colors.blueAccent
        : ((_partnerIsOnline || isAdmin)
              ? Colors.greenAccent.shade400
              : Colors.grey.shade400);

    if (!_partnerIsTyping && !isAdmin) {
      if (_partnerIsOnline) {
        statusText = 'В сети';
      } else if (_partnerLastSeen != null) {
        final lastSeen = _partnerLastSeen!.toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final msgDay = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);

        if (msgDay == today) {
          statusText = 'Сегодня в ${DateFormat('HH:mm').format(lastSeen)}';
        } else if (msgDay == yesterday) {
          statusText = 'Вчера в ${DateFormat('HH:mm').format(lastSeen)}';
        } else {
          statusText =
              '${DateFormat('d MMM', 'ru').format(lastSeen)} в ${DateFormat('HH:mm').format(lastSeen)}';
        }
      }
    }

    final hasAvatar =
        widget.partnerAvatar != null && widget.partnerAvatar!.trim().isNotEmpty;

    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: hasAvatar
                  ? NetworkImage(widget.partnerAvatar!)
                  : null,
              child: !hasAvatar
                  ? Icon(
                      isAdmin ? Icons.support_agent : Icons.person,
                      color: Colors.grey.shade700,
                      size: 20,
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (widget.partnerName != null &&
                        widget.partnerName!.trim().isNotEmpty)
                    ? widget.partnerName!
                    : 'Чат ${widget.partnerId.length >= 6 ? widget.partnerId.substring(0, 6) : widget.partnerId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _partnerIsTyping
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: _partnerIsTyping
                      ? Colors.blueAccent.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    if (_isCurrentlyTyping && widget.partnerId.isNotEmpty) {
      _socket?.emit('stop_typing', {'receiverId': widget.partnerId});
    }

    // ✅ FIXED: Use cached references instead of ref.read() inside dispose()
    _activeSessionNotifier?.state = null;
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();

    _socket?.stopListening('user_typing', _onPartnerTyping);
    _socket?.stopListening('user_stopped_typing', _onPartnerStoppedTyping);
    _socket?.stopListening('user_status_changed', _onUserStatusChanged);
    _socket?.stopListening('user_presence', _onUserStatusChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesProvider(_currentSessionId));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id']?.toString() ?? '';

    ref.listen(chatMessagesProvider(_currentSessionId), (previous, next) {
      final currentMessages = next.valueOrNull;
      final previousMessages = previous?.valueOrNull;

      if (currentMessages != null && previousMessages != null) {
        if (currentMessages.length > previousMessages.length) {
          if (_scrollController.hasClients && _scrollController.offset < 100) {
            _scrollToBottom();
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: _buildAppBarTitle(),
      ),
      body: Column(
        children: [
          // Optional Job Context Bar when opened from JobDetailScreen
          if (widget.jobId != null && widget.jobId!.isNotEmpty)
            InkWell(
              onTap: () =>
                  context.push('${AppRoutes.jobDetail}/${widget.jobId}'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.work_outline_rounded,
                      size: 18,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.jobTitle != null && widget.jobTitle!.isNotEmpty
                            ? 'Заказ: ${widget.jobTitle}'
                            : 'Перейти к деталям заказа',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: messagesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Ошибка загрузки: $error')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Напишите первое сообщение',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                if (messages.isNotEmpty &&
                    messages.first.senderId == widget.partnerId &&
                    !messages.first.isRead) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ref
                          .read(
                            chatMessagesProvider(_currentSessionId).notifier,
                          )
                          .markAsRead(widget.partnerId);
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length + (_partnerIsTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_partnerIsTyping) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            bottom: 8,
                            top: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Печатает...',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      index -= 1;
                    }

                    final msg = messages[index];
                    final msgDate =
                        (DateTime.tryParse(msg.createdAt) ?? DateTime.now())
                            .toLocal();

                    bool showDateSeparator = false;

                    // ✅ FIXED: Restored subtraction operator `- 1`
                    if (index == messages.length - 1) {
                      showDateSeparator = true;
                    } else {
                      final nextOlderMsg = messages[index + 1];
                      final nextOlderDate =
                          (DateTime.tryParse(nextOlderMsg.createdAt) ??
                                  DateTime.now())
                              .toLocal();

                      if (msgDate.year != nextOlderDate.year ||
                          msgDate.month != nextOlderDate.month ||
                          msgDate.day != nextOlderDate.day) {
                        showDateSeparator = true;
                      }
                    }

                    final bubble = ChatBubble(
                      message: msg,
                      isMe: msg.senderId == currentUserId,
                    );

                    if (showDateSeparator) {
                      return Column(
                        children: [_buildDateSeparator(msgDate), bubble],
                      );
                    }

                    return bubble;
                  },
                );
              },
            ),
          ),
          ChatInput(
            isUploading: _isUploading,
            onSend: (text) async {
              _typingDebounce?.cancel();
              if (_isCurrentlyTyping) {
                _isCurrentlyTyping = false;
                _socket?.emit('stop_typing', {'receiverId': widget.partnerId});
              }

              final newSessionId = await ref
                  .read(chatMessagesProvider(_currentSessionId).notifier)
                  .sendMessage(text: text, receiverId: widget.partnerId);

              _handleSessionUpgrade(newSessionId);
              _scrollToBottom();
            },
            onTyping: _handleUserTyping,
            onAttachmentPressed: _showAttachmentOptions,
          ),
        ],
      ),
    );
  }
}
