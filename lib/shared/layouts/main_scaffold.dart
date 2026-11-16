import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/chat_sessions_provider.dart';
import 'profile_drawer.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDrawerOpen = false;

  void _onTabClick(int index) {
    // TAB 3: PROFILE DRAWER
    if (index == 3) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }

    // TAB 1 & 2: RESTRICTED TABS (Orders & Chat) REQUIRE AUTHENTICATION
    if (index == 1 || index == 2) {
      final bool isAuth = ref.read(isAuthenticatedProvider);
      if (!isAuth) {
        context.push(AppRoutes.login);
        return;
      }
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isAuth = ref.watch(isAuthenticatedProvider);

    // ✅ Only watch chatSessionsProvider when authenticated to prevent 401 errors on startup
    final int totalUnreadCount = isAuth
        ? ref
              .watch(chatSessionsProvider)
              .maybeWhen(
                data: (sessions) => sessions.fold<int>(
                  0,
                  (sum, session) => sum + session.unreadCount,
                ),
                orElse: () => 0,
              )
        : 0;

    return PopScope(
      canPop: currentIndex == 0 && !_isDrawerOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If the Profile Drawer is open, close it first
        if (_isDrawerOpen ||
            (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        // 2. Otherwise return to Home tab (Tab 0)
        if (currentIndex != 0) {
          _onTabClick(0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const ProfileDrawer(),
        onDrawerChanged: (isOpened) {
          if (_isDrawerOpen != isOpened) {
            setState(() => _isDrawerOpen = isOpened);
          }
        },
        body: widget.navigationShell,
        extendBody: true,
        bottomNavigationBar: Container(
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: LucideIcons.house,
                      label: 'Главная',
                      isSelected: currentIndex == 0,
                      onTap: () => _onTabClick(0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: LucideIcons.clipboard_list,
                      label: 'Заказы',
                      isSelected: currentIndex == 1,
                      onTap: () => _onTabClick(1),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: LucideIcons.message_circle_more,
                      label: 'Чат',
                      isSelected: currentIndex == 2,
                      badge: totalUnreadCount,
                      onTap: () => _onTabClick(2),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: LucideIcons.user,
                      label: 'Профиль',
                      isSelected: _isDrawerOpen,
                      onTap: () => _onTabClick(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF0F172A) : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 24),
              Positioned(
                right: -10,
                top: -6,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: badge > 0
                      ? Container(
                          key: ValueKey<int>(badge),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badge > 99 ? '99+' : badge.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey<int>(0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// ANIMATED TAB STACK
// =======================================================
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}
