import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/utils/phone_formatter.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/providers/notification_provider.dart';

final isAvatarUploadingProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final user = ref.watch(currentUserProvider);
    final isUploading = ref.watch(isAvatarUploadingProvider);
    final unreadNotifications = isAuthenticated
        ? ref.watch(unreadCountProvider)
        : 0;

    final String? avatarUrl =
        user?['image']?.toString() ?? user?['photo']?.toString();
    final bool hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    String name =
        user?['name']?.toString() ?? user?['first_name']?.toString() ?? '';
    if (name.trim().isEmpty) name = 'Партнер';

    final String? mobile = user?['mobile']?.toString();
    final String? email = user?['email']?.toString();

    return Drawer(
      // ✅ FIXED: Restored multiplication operator `* 0.85`
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Меню профиля',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  if (isAuthenticated) ...[
                    // ==========================================
                    // LOGGED IN HEADER WITH AVATAR STACK
                    // ==========================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  image: hasAvatar
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(
                                            avatarUrl,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: !hasAvatar
                                    ? const Icon(
                                        LucideIcons.user,
                                        color: Color(0xFF0F172A),
                                        size: 28,
                                      )
                                    : null,
                              ),
                              if (isUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black26,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
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
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (mobile != null && mobile.isNotEmpty)
                                  Text(
                                    PhoneFormatter.format(mobile),
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (email != null && email.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    _MenuItem(
                      icon: LucideIcons.user_pen,
                      title: 'Редактировать профиль',
                      subtitle: 'Личные данные, категории и авто',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.profileEdit);
                      },
                    ),
                    _MenuItem(
                      icon: LucideIcons.credit_card,
                      title: 'Реквизиты и выплаты',
                      subtitle: 'ИНН и номер карты для доходов',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.workerStep4);
                      },
                    ),
                    _MenuItem(
                      icon: LucideIcons.clipboard_list,
                      title: 'История заказов',
                      subtitle: 'Выполненные заявки и отчеты',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('${AppRoutes.jobList}?status=COMPLETED');
                      },
                    ),
                    _MenuItem(
                      icon: LucideIcons.bell,
                      title: 'Уведомления',
                      subtitle: 'Оповещения по заказам и системе',
                      badgeCount: unreadNotifications,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.notifications);
                      },
                    ),
                    const Divider(height: 32, color: Color(0xFFF1F5F9)),
                  ] else ...[
                    // ==========================================
                    // NOT LOGGED IN HEADER
                    // ==========================================
                    Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            LucideIcons.user,
                            size: 40,
                            color: Color(0xFF0F172A),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Войдите, чтобы принимать заказы и зарабатывать.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _MenuItem(
                      icon: LucideIcons.log_in,
                      title: 'Вход и Регистрация',
                      subtitle: 'Войти или создать аккаунт партнера',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.login);
                      },
                    ),
                  ],

                  // ==========================================
                  // COMMON LINKS
                  // ==========================================
                  _MenuItem(
                    icon: LucideIcons.message_square_text,
                    title: 'Служба поддержки',
                    subtitle: 'Помощь и вопросы по заказам',
                    iconColor: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (!isAuthenticated) {
                        context.push(AppRoutes.login);
                      } else {
                        context.push(AppRoutes.support);
                      }
                    },
                  ),
                  if (isAuthenticated) ...[
                    const Divider(height: 32, color: Color(0xFFF1F5F9)),
                    _MenuItem(
                      icon: LucideIcons.log_out,
                      title: 'Выйти',
                      subtitle: 'Завершить сеанс',
                      iconColor: Colors.red,
                      isDestructive: true,
                      onTap: () async {
                        // ✅ FIXED: Close drawer first, then execute logout
                        Navigator.of(context).pop();
                        await ref.read(authControllerProvider).logout(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final bool isDestructive;
  final int badgeCount;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = const Color(0xFF0F172A),
    this.isDestructive = false,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDestructive ? Colors.red : Colors.grey).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDestructive
                          ? Colors.red
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
