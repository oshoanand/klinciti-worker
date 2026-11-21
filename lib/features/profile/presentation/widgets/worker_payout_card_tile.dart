import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../payments/providers/payment_provider.dart';

class WorkerPayoutCardTile extends ConsumerWidget {
  const WorkerPayoutCardTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(linkedCardsProvider);

    return cardsAsync.when(
      loading: () => _buildContainer(
        onTap: () => context.push(AppRoutes.paymentMethods),
        icon: LucideIcons.wallet,
        accentColor: const Color(0xFF0F172A),
        title: 'Карты для выплат',
        subtitle: 'Загрузка привязанных карт...',
      ),
      error: (_, __) => _buildContainer(
        onTap: () => context.push(AppRoutes.paymentMethods),
        icon: LucideIcons.wallet,
        accentColor: const Color(0xFF0F172A),
        title: 'Карты для выплат',
        subtitle: 'Нажмите для настройки выплат',
      ),
      data: (cards) {
        if (cards.isEmpty) {
          // Prompt worker to link a card so Safe Deal E2C payouts succeed automatically
          return _buildContainer(
            onTap: () => context.push(AppRoutes.paymentMethods),
            icon: LucideIcons.triangle_alert,
            accentColor: Colors.deepOrange,
            borderColor: Colors.deepOrange.withValues(alpha: 0.35),
            backgroundColor: Colors.deepOrange.withValues(alpha: 0.04),
            title: 'Привяжите карту для выплат',
            subtitle: 'Необходимо для автоматического получения оплаты',
            badgeText: 'Требуется',
          );
        }

        final defaultCard = cards.firstWhere(
          (c) => c.isDefault,
          orElse: () => cards.first,
        );
        final brand = defaultCard.cardType ?? 'Карта';

        return _buildContainer(
          onTap: () => context.push(AppRoutes.paymentMethods),
          icon: LucideIcons.wallet,
          accentColor: Colors.teal,
          title: 'Карты для выплат',
          subtitle: 'Основная: $brand •••• ${defaultCard.lastFour}',
          badgeText: 'Активна',
        );
      },
    );
  }

  Widget _buildContainer({
    required VoidCallback onTap,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? borderColor,
    Color? backgroundColor,
  }) {
    return Material(
      color: backgroundColor ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevron_right,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
