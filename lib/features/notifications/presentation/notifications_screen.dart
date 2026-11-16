import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/global_error_widget.dart';
import '../providers/notification_provider.dart';

class NotifStyle {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const NotifStyle(this.icon, this.bgColor, this.iconColor);
}

NotifStyle _getStyle(String type) {
  final upper = type.toUpperCase();
  if (upper.contains('JOB') || upper.contains('ORDER')) {
    return NotifStyle(
      LucideIcons.package,
      Colors.blue.shade50,
      Colors.blue.shade600,
    );
  }
  if (upper.contains('CHAT') || upper.contains('MESSAGE')) {
    return NotifStyle(
      LucideIcons.message_square,
      Colors.green.shade50,
      Colors.green.shade600,
    );
  }
  if (upper.contains('ALERT') ||
      upper.contains('REJECT') ||
      upper.contains('DISPUTE')) {
    return NotifStyle(
      LucideIcons.triangle_alert,
      Colors.red.shade50,
      Colors.red.shade600,
    );
  }
  return NotifStyle(
    LucideIcons.info,
    Colors.grey.shade100,
    Colors.grey.shade600,
  );
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Safely resolves notification payloads and legacy backend URLs to valid GoRouter paths
  void _handleNotificationTap(
    BuildContext context,
    NotificationNotifier notifier,
    NotificationModel notif,
  ) {
    if (!notif.isRead) {
      notifier.markAsRead(notif.id);
    }

    final data = notif.data ?? const <String, dynamic>{};
    final String notifType = (data['type']?.toString() ?? notif.type)
        .toUpperCase();
    final String? rawUrl = data['url']?.toString();
    final String? sessionId =
        data['sessionId']?.toString() ?? data['chatSessionId']?.toString();
    final String? partnerId =
        data['partnerId']?.toString() ?? data['senderId']?.toString();
    final String? jobId =
        data['jobId']?.toString() ?? data['orderId']?.toString();

    // 1. Direct Job Detail routing if jobId is present
    if (jobId != null && jobId.isNotEmpty) {
      context.push('${AppRoutes.jobDetail}/$jobId');
      return;
    }

    // 2. Direct Chat Room routing if sessionId is present
    if (sessionId != null && sessionId.isNotEmpty) {
      final uri = Uri(
        path: '${AppRoutes.chatDetail}/$sessionId',
        queryParameters: {
          if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
        },
      );
      context.push(uri.toString());
      return;
    }

    // 3. Parse backend `url` field (e.g., `/chat/:sessionId/:partnerId` or `/jobs/detail/:id`)
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      final cleanUrl = rawUrl.trim();

      // Convert backend `/chat/:sessionId/:partnerId` -> `/chats/room/:sessionId?partnerId=...`
      if (cleanUrl.startsWith('/chat/')) {
        final parts = cleanUrl.split('/').where((s) => s.isNotEmpty).toList();
        if (parts.length >= 2) {
          final parsedSessionId = parts[1];
          final parsedPartnerId = parts.length >= 3 ? parts[2] : '';
          final uri = Uri(
            path: '${AppRoutes.chatDetail}/$parsedSessionId',
            queryParameters: {
              if (parsedPartnerId.isNotEmpty) 'partnerId': parsedPartnerId,
            },
          );
          context.push(uri.toString());
          return;
        }
      }

      // Convert `/chat-detail/:sessionId` -> `/chats/room/:sessionId`
      if (cleanUrl.startsWith('/chat-detail/')) {
        final parsedSessionId = cleanUrl.replaceFirst('/chat-detail/', '');
        context.push('${AppRoutes.chatDetail}/$parsedSessionId');
        return;
      }

      // Otherwise push the URL if it matches a valid route pattern
      context.push(cleanUrl);
      return;
    }

    // 4. Fallback by notification type
    if (notifType.contains('JOB') || notifType.contains('ORDER')) {
      context.go(AppRoutes.jobDashboard);
    } else if (notifType.contains('CHAT')) {
      context.go(AppRoutes.chatList);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Уведомления',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () => notifier.markAllAsRead(),
              icon: const Icon(
                LucideIcons.check_check,
                size: 18,
                color: Color(0xFF0F172A),
              ),
              label: const Text(
                'Прочитать все',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F172A)),
        ),
        error: (error, _) {
          final apiError = ApiException.fromDioException(error);
          return GlobalErrorWidget(
            message: apiError.message,
            onRetry: () => notifier.fetchInitial(),
          );
        },
        data: (notifications) {
          if (notifications.isEmpty) {
            return RefreshIndicator(
              color: const Color(0xFF0F172A),
              onRefresh: () => notifier.fetchInitial(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.bell,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'У вас нет уведомлений',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Здесь будут появляться сообщения о статусе заказов, ответы поддержки и системные оповещения.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF0F172A),
            onRefresh: () => notifier.fetchInitial(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final String notifType =
                    notif.data?['type']?.toString() ?? notif.type;
                final style = _getStyle(notifType);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        _handleNotificationTap(context, notifier, notif),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: !notif.isRead
                            ? const Color(0xFF0F172A).withValues(alpha: 0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !notif.isRead
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Unread Indicator Bar
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: !notif.isRead
                                    ? const Color(0xFF0F172A)
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: style.bgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        style.icon,
                                        color: style.iconColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notif.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: !notif.isRead
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: !notif.isRead
                                                  ? const Color(0xFF0F172A)
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                          if (notif.message.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              notif.message,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: !notif.isRead
                                                    ? Colors.black87
                                                    : Colors.grey.shade500,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            DateFormatter.formatTimeAgo(
                                              (DateTime.tryParse(
                                                        notif.createdAt,
                                                      ) ??
                                                      DateTime.now())
                                                  .toLocal(),
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!notif.isRead)
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          top: 6,
                                          left: 8,
                                        ),
                                        child: Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
