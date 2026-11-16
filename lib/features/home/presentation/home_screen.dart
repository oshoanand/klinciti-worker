import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/global_error_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../jobs/providers/job_provider.dart';
import '../../notifications/providers/notification_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleRefresh(WidgetRef ref, bool isAuth) async {
    if (isAuth) {
      await Future.wait([
        ref.refresh(jobStatsProvider.future),
        ref.read(notificationsProvider.notifier).fetchInitial(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isAuth = ref.watch(isAuthenticatedProvider);
    final user = ref.watch(currentUserProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.briefcase,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Klinciti Партнер',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          actions: [
            if (isAuth)
              Consumer(
                builder: (context, ref, child) {
                  final unreadCount = ref.watch(unreadCountProvider);
                  return IconButton(
                    tooltip: 'Уведомления',
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(LucideIcons.bell, color: Colors.white),
                        if (unreadCount > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
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
                                border: Border.all(
                                  color: const Color(0xFF0F172A),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () => context.push(AppRoutes.notifications),
                  );
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _handleRefresh(ref, isAuth),
          color: const Color(0xFF0F172A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ==========================================
              // 1. WORKER HERO SECTION
              // ==========================================
              SliverToBoxAdapter(
                child: _buildHeroSection(context, isAuth, user),
              ),

              // ==========================================
              // 2. AUTHENTICATED WORKER LIVE SUMMARY
              // ==========================================
              if (isAuth)
                SliverToBoxAdapter(
                  child: _buildAuthenticatedWorkerBody(context, ref),
                ),

              // ==========================================
              // 3. HOW IT WORKS / WORKER STANDARDS
              // ==========================================
              SliverToBoxAdapter(child: _buildWorkflowSection(context, isAuth)),

              // Extra bottom spacing for floating MainScaffold nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 1. WORKER HERO SECTION BUILDER
  // ============================================================
  Widget _buildHeroSection(
    BuildContext context,
    bool isAuth,
    Map<String, dynamic>? user,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    final rawName =
        user?['first_name']?.toString() ?? user?['name']?.toString() ?? '';
    final firstName = rawName.trim().split(' ').first;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding + 64),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAuth)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: Color(0xFF34D399)),
                        SizedBox(width: 6),
                        Text(
                          'Аккаунт активен • Готов к заказам',
                          style: TextStyle(
                            color: Color(0xFFD1FAE5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  isAuth && firstName.isNotEmpty
                      ? 'Здравствуйте,\n$firstName!'
                      : 'Зарабатывайте на\nсвоих услугах',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isAuth
                      ? 'Проверяйте назначенные заявки, согласовывайте бюджет с клиентом и отправляйте фотоотчеты.'
                      : 'Присоединяйтесь к платформе Klinciti, выполняйте заказы в своем городе и получайте стабильный доход.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),

                if (!isAuth) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.login),
                      icon: const Icon(LucideIcons.log_in, size: 18),
                      label: const Text(
                        'Войти или стать партнером',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // HORIZONTAL WORKER BENEFITS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFeatureCard(
                  icon: LucideIcons.badge_percent,
                  title: 'Без комиссии',
                  subtitle: 'Честные условия',
                ),
                _buildFeatureCard(
                  icon: LucideIcons.wallet,
                  title: 'Быстрые выплаты',
                  subtitle: 'Прямо на карту',
                ),
                _buildFeatureCard(
                  icon: LucideIcons.calendar_check,
                  title: 'Гибкий график',
                  subtitle: 'Работайте когда удобно',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 2. AUTHENTICATED WORKER DASHBOARD OVERVIEW
  // ============================================================
  Widget _buildAuthenticatedWorkerBody(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(jobStatsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statsAsync.when(
            loading: () => Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              ),
            ),
            error: (err, _) => GlobalErrorWidget(
              message: ApiException.fromDioException(err).message,
              onRetry: () => ref.refresh(jobStatsProvider),
            ),
            data: (stats) => _buildStatsAndEarningsSection(context, stats),
          ),

          const SizedBox(height: 24),
          const Text(
            'Управление профилем',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Actions Row
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: LucideIcons.sliders_horizontal,
                  title: 'Анкета и авто',
                  subtitle: 'Услуги и данные',
                  color: const Color(0xFF3B82F6),
                  onTap: () => context.push(AppRoutes.profileEdit),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionTile(
                  icon: LucideIcons.credit_card,
                  title: 'Реквизиты',
                  subtitle: 'Карта и ИНН',
                  color: const Color(0xFF10B981),
                  onTap: () => context.push(AppRoutes.workerStep4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionTile(
                  icon: LucideIcons.headphones,
                  title: 'Поддержка',
                  subtitle: 'Чат с админом',
                  color: const Color(0xFFF59E0B),
                  onTap: () => context.push(AppRoutes.support),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAFE STATS EXTRACTION HELPERS
  // Works seamlessly whether jobStatsProvider returns a typed class or a Map
  // ============================================================
  double _readDouble(
    dynamic stats,
    List<String> keys,
    double Function() getter,
  ) {
    try {
      return getter();
    } catch (_) {
      if (stats is Map) {
        for (final k in keys) {
          final v = stats[k];
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v) ?? 0.0;
        }
      }
      return 0.0;
    }
  }

  int _readInt(dynamic stats, List<String> keys, int Function() getter) {
    try {
      return getter();
    } catch (_) {
      if (stats is Map) {
        for (final k in keys) {
          final v = stats[k];
          if (v is num) return v.toInt();
          if (v is String) return int.tryParse(v) ?? 0;
        }
      }
      return 0;
    }
  }

  // ============================================================
  // STATS & EARNINGS SECTION BUILDER
  // ============================================================
  Widget _buildStatsAndEarningsSection(BuildContext context, dynamic stats) {
    final totalEarnings = _readDouble(stats, [
      'totalEarnings',
      'total_earnings',
    ], () => (stats.totalEarnings as num).toDouble());
    final paidEarnings = _readDouble(stats, [
      'paidEarnings',
      'paid_earnings',
    ], () => (stats.paidEarnings as num).toDouble());
    final pendingEarnings = _readDouble(stats, [
      'pendingEarnings',
      'pending_earnings',
    ], () => (stats.pendingEarnings as num).toDouble());

    final acceptedCount = _readInt(stats, [
      'acceptedCount',
      'accepted_count',
      'ACCEPTED',
    ], () => (stats.acceptedCount as num).toInt());
    final ongoingCount = _readInt(stats, [
      'ongoingCount',
      'ongoing_count',
      'ONGOING',
    ], () => (stats.ongoingCount as num).toInt());
    final completedCount = _readInt(stats, [
      'completedCount',
      'completed_count',
      'COMPLETED',
    ], () => (stats.completedCount as num).toInt());
    final disputedCount = _readInt(stats, [
      'disputedCount',
      'disputed_count',
      'DISPUTED',
    ], () => (stats.disputedCount as num).toInt());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Earnings Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.wallet,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Общий доход',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${totalEarnings.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.workerStep4),
                    child: const Text(
                      'Реквизиты',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Выплачено',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${paidEarnings.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ожидает выплаты',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pendingEarnings.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 2. Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Сводка по заказам',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.jobDashboard),
              child: const Text('Все заказы'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. 2x2 Status Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _StatusMiniCard(
              title: 'Новые заявки',
              count: acceptedCount,
              icon: LucideIcons.bell_ring,
              color: const Color(0xFF3B82F6),
              onTap: () => context.push('${AppRoutes.jobList}?status=ACCEPTED'),
            ),
            _StatusMiniCard(
              title: 'В работе',
              count: ongoingCount,
              icon: LucideIcons.play,
              color: const Color(0xFFF59E0B),
              onTap: () => context.push('${AppRoutes.jobList}?status=ONGOING'),
            ),
            _StatusMiniCard(
              title: 'Выполнено',
              count: completedCount,
              icon: LucideIcons.circle_check,
              color: const Color(0xFF10B981),
              onTap: () =>
                  context.push('${AppRoutes.jobList}?status=COMPLETED'),
            ),
            _StatusMiniCard(
              title: 'Споры',
              count: disputedCount,
              icon: LucideIcons.shield_alert,
              color: const Color(0xFFEF4444),
              onTap: () => context.push('${AppRoutes.jobList}?status=DISPUTED'),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // 3. WORKER WORKFLOW & PLATFORM RULES
  // ============================================================
  Widget _buildWorkflowSection(BuildContext context, bool isAuth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Порядок выполнения заказов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                _WorkflowStepTile(
                  number: '1',
                  title: 'Получение заявки',
                  description: 'Новые заказы по вашей специализации поступают в раздел «Новые заявки» с push-уведомлением.',
                ),
                Divider(height: 24, color: Color(0xFFF1F5F9)),
                _WorkflowStepTile(
                  number: '2',
                  title: 'Связь с клиентом и подтверждение',
                  description: 'Свяжитесь с заказчиком в чате или по телефону, укажите итоговую стоимость и нажмите «Принять в работу».',
                ),
                Divider(height: 24, color: Color(0xFFF1F5F9)),
                _WorkflowStepTile(
                  number: '3',
                  title: 'Фотоотчет о выполнении',
                  description: 'После завершения работы прикрепите фотографии результата в карточке заказа.',
                ),
                Divider(height: 24, color: Color(0xFFF1F5F9)),
                _WorkflowStepTile(
                  number: '4',
                  title: 'Быстрая выплата на карту',
                  description: 'Вознаграждение перечисляется по вашим реквизитам после закрытия заявки.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMiniCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusMiniCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowStepTile extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _WorkflowStepTile({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
