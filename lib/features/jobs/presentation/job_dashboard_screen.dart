import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../shared/widgets/global_error_widget.dart';
import '../providers/job_provider.dart';
import '../../../core/router/route_names.dart';

class JobDashboardScreen extends ConsumerWidget {
  const JobDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(jobStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Мои задания',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refresh_cw, size: 20),
            tooltip: 'Обновить',
            onPressed: () => ref.invalidate(jobStatsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(jobStatsProvider.future),
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => GlobalErrorWidget(
            message: ApiException.fromDioException(err).message,
            onRetry: () => ref.refresh(jobStatsProvider.future),
          ),
          data: (stats) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              children: [
                // Summary Banner for Completed vs Pending Payouts
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BannerStatItem(
                          label: 'Ожидают оплаты',
                          count: stats.paymentPending,
                          color: const Color(0xFFFBBF24),
                          onTap: () => context.push(
                            '${AppRoutes.jobList}?status=PAYMENT_PENDING',
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 44,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _BannerStatItem(
                          label: 'Оплачено',
                          count: stats.paid,
                          color: const Color(0xFF34D399),
                          onTap: () =>
                              context.push('${AppRoutes.jobList}?status=PAID'),
                        ),
                      ),
                    ],
                  ),
                ),

                const Text(
                  'Категории заявок',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Incoming Requests (Backend status: ACCEPTED)
                _StatCard(
                  title: 'Входящие запросы',
                  subtitle: 'Назначены вам и ждут подтверждения',
                  count: stats.accepted,
                  icon: LucideIcons.bell_ring,
                  color: Colors.amber.shade800,
                  bgColor: Colors.amber.shade50,
                  highlightBadge: stats.accepted > 0,
                  onTap: () =>
                      context.push('${AppRoutes.jobList}?status=ACCEPTED'),
                ),

                // 2. Ongoing Jobs (Backend status: ONGOING)
                _StatCard(
                  title: 'В работе (Активные)',
                  subtitle: 'Текущие выполняемые заказы',
                  count: stats.ongoing,
                  icon: LucideIcons.timer,
                  color: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  onTap: () =>
                      context.push('${AppRoutes.jobList}?status=ONGOING'),
                ),

                // 3. Completed Jobs (Backend status: COMPLETED)
                _StatCard(
                  title: 'Выполненные',
                  subtitle: 'Все успешно завершенные заказы',
                  count: stats.completed,
                  icon: LucideIcons.circle_check,
                  color: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  onTap: () =>
                      context.push('${AppRoutes.jobList}?status=COMPLETED'),
                ),

                // 4. Disputed Jobs (Backend status: DISPUTED)
                _StatCard(
                  title: 'Спорные ситуации',
                  subtitle: 'Заказы на рассмотрении у модератора',
                  count: stats.disputed,
                  icon: LucideIcons.shield_alert,
                  color: Colors.orange.shade800,
                  bgColor: Colors.orange.shade50,
                  onTap: () =>
                      context.push('${AppRoutes.jobList}?status=DISPUTED'),
                ),

                // 5. Rejected / Refused Jobs (Backend status: REFUSED)
                _StatCard(
                  title: 'Отклоненные',
                  subtitle: 'Непринятые или возвращенные заказы',
                  count: stats.refused,
                  icon: LucideIcons.ban,
                  color: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                  onTap: () =>
                      context.push('${AppRoutes.jobList}?status=REFUSED'),
                ),

                // 6. Cancelled Jobs (Backend status: CANCELLED)
                _StatCard(
                  title: 'Отмененные клиентом',
                  subtitle: 'Заявки, снятые заказчиком',
                  count: stats.cancelled,
                  icon: LucideIcons.circle_x,
                  color: Colors.blueGrey.shade600,
                  bgColor: Colors.blueGrey.shade50,
                  onTap: () =>
                      context.push('${AppRoutes.jobList}?status=CANCELLED'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BannerStatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _BannerStatItem({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool highlightBadge;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.highlightBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlightBadge
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
            : Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: count > 0 ? bgColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: count > 0 ? color : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.chevron_right,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
