import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../data/models/chat_session_model.dart';
import '../../providers/chat_sessions_provider.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  bool _isAdminSession(ChatSessionModel session) {
    if (session.isAdmin) return true;
    final name = session.partnerName?.toLowerCase() ?? '';
    return name.contains('admin') ||
        name.contains('support') ||
        name.contains('поддержка');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsState = ref.watch(chatSessionsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: Icon(
              LucideIcons.message_circle_more,
              color: Color(0xFF0F172A),
            ),
          ),
          title: const Text(
            'Список чатов',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
              fontSize: 22,
            ),
          ),
          centerTitle: false,
        ),
        body: RefreshIndicator(
          color: const Color(0xFF0F172A),
          backgroundColor: Colors.white,
          onRefresh: () => ref.read(chatSessionsProvider.notifier).refresh(),
          child: sessionsState.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            ),
            error: (err, _) => Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.circle_alert,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ошибка загрузки\n$err',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(chatSessionsProvider.notifier).refresh(),
                      icon: const Icon(LucideIcons.refresh_cw, size: 16),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
            data: (sessions) {
              // 1. Determine if we need to show the injected support card
              final hasActiveAdminSession = sessions.any(_isAdminSession);
              final showPinnedSupport = !hasActiveAdminSession;

              // 2. Handle completely empty state
              if (sessions.isEmpty && !showPinnedSupport) {
                return _buildEmptyState();
              }

              // 3. SORTING LOGIC: Pin Support/Admins to the top, then sort by latest message
              final sortedSessions = List.of(sessions)
                ..sort((a, b) {
                  final aIsAdmin = _isAdminSession(a);
                  final bIsAdmin = _isAdminSession(b);

                  if (aIsAdmin && !bIsAdmin) return -1;
                  if (!aIsAdmin && bIsAdmin) return 1;

                  final aDate =
                      DateTime.tryParse(a.updatedAt) ?? DateTime.now();
                  final bDate =
                      DateTime.tryParse(b.updatedAt) ?? DateTime.now();
                  return bDate.compareTo(aDate);
                });

              final itemCount = showPinnedSupport
                  ? sortedSessions.length + 1
                  : sortedSessions.length;

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                // Extra bottom padding so floating bottom nav bar doesn't cover items
                padding: const EdgeInsets.only(top: 8, bottom: 110),
                itemCount: itemCount,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(left: 88, right: 24),
                  child: Divider(height: 1, color: Colors.grey.shade200),
                ),
                itemBuilder: (context, index) {
                  // 4. Inject Pinned Support Card at index 0 if required
                  if (showPinnedSupport && index == 0) {
                    return _buildPinnedSupportCard(context);
                  }

                  // ✅ FIXED: Restored subtraction operator `- 1`
                  final sessionIndex = showPinnedSupport ? index - 1 : index;
                  final session = sortedSessions[sessionIndex];

                  final date =
                      (DateTime.tryParse(session.updatedAt) ?? DateTime.now())
                          .toLocal();
                  final isUnread = session.unreadCount > 0;
                  final isAdmin = _isAdminSession(session);
                  final hasAvatar =
                      session.partnerAvatar != null &&
                      session.partnerAvatar!.trim().isNotEmpty;

                  return Material(
                    color: isAdmin
                        ? Colors.blue.shade50.withValues(alpha: 0.3)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // ✅ FIXED: Route matches app_router.dart ('/chats/room/:sessionId')
                        final targetUri = Uri(
                          path: '${AppRoutes.chatDetail}/${session.id}',
                          queryParameters: {
                            'partnerId': session.partnerId,
                            if (session.partnerName != null)
                              'partnerName': session.partnerName!,
                            if (hasAvatar)
                              'partnerAvatar': session.partnerAvatar!,
                          },
                        );

                        context.push(targetUri.toString(), extra: session);
                      },
                      highlightColor: Colors.grey.shade100,
                      splashColor: Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: isAdmin
                                      ? const Color(0xFF3B82F6)
                                            .withValues(alpha: 0.1)
                                      : const Color(0xFF0F172A)
                                            .withValues(alpha: 0.05),
                                  backgroundImage: hasAvatar
                                      ? NetworkImage(session.partnerAvatar!)
                                      : null,
                                  child: !hasAvatar
                                      ? Icon(
                                          isAdmin
                                              ? LucideIcons.shield_check
                                              : LucideIcons.user,
                                          color: isAdmin
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFF64748B),
                                          size: 24,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: (session.isOnline || isAdmin)
                                          ? Colors.green
                                          : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                (session.partnerName != null &&
                                                        session.partnerName!
                                                            .trim()
                                                            .isNotEmpty)
                                                    ? session.partnerName!
                                                    : 'ID: ${session.partnerId.length >= 6 ? session.partnerId.substring(0, 6) : session.partnerId}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: isUnread
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  fontSize: 16,
                                                  color: isAdmin
                                                      ? const Color(0xFF3B82F6)
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            if (isAdmin)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 6.0,
                                                ),
                                                child: Icon(
                                                  LucideIcons.badge_check,
                                                  size: 16,
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatLastMessageDate(date),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isUnread
                                              ? const Color(0xFF3B82F6)
                                              : Colors.grey.shade500,
                                          fontWeight: isUnread
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: session.isTyping
                                            ? const Text(
                                                'Печатает...',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Color(0xFF3B82F6),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              )
                                            : Text(
                                                (session.lastMessage != null &&
                                                        session.lastMessage!
                                                            .trim()
                                                            .isNotEmpty)
                                                    ? session.lastMessage!
                                                    : 'Начните диалог',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isUnread
                                                      ? const Color(0xFF0F172A)
                                                      : Colors.grey.shade600,
                                                  fontWeight: isUnread
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  fontSize: 14,
                                                ),
                                              ),
                                      ),
                                      if (isUnread)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF3B82F6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            session.unreadCount > 99
                                                ? '99+'
                                                : session.unreadCount
                                                      .toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // PINNED SUPPORT CARD (Routes to AppRoutes.support)
  // ====================================================================
  Widget _buildPinnedSupportCard(BuildContext context) {
    return Material(
      color: Colors.blue.shade50.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () {
          // ✅ FIXED: Uses registered support route ('/support')
          context.push(AppRoutes.support);
        },
        highlightColor: Colors.grey.shade100,
        splashColor: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                child: const Icon(
                  LucideIcons.shield_check,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Служба поддержки',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 6.0),
                          child: Icon(
                            LucideIcons.badge_check,
                            size: 16,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Напишите нам, если у вас есть вопросы',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.message_square,
                  size: 40,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Нет активных чатов',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Здесь появятся ваши переписки\nс заказчиками и поддержкой.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLastMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) {
      return DateFormat('HH:mm').format(date);
    } else if (msgDay == yesterday) {
      return 'Вчера';
    } else {
      return DateFormat('dd.MM.yy').format(date);
    }
  }
}
