import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exceptions.dart';
import '../providers/payment_provider.dart';

class LinkedCardsScreen extends ConsumerStatefulWidget {
  /// Set true in the Worker App (E2C payout cards), false in the Customer App (Acquiring cards)
  final bool isWorkerPayoutMode;

  const LinkedCardsScreen({super.key, this.isWorkerPayoutMode = false});

  @override
  ConsumerState<LinkedCardsScreen> createState() => _LinkedCardsScreenState();
}

class _LinkedCardsScreenState extends ConsumerState<LinkedCardsScreen>
    with WidgetsBindingObserver {
  bool _awaitingTBankReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Automatically syncs card list with T-Bank when returning from 3DS verification
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingTBankReturn) {
      _awaitingTBankReturn = false;
      ref.invalidate(linkedCardsProvider);
    }
  }

  Future<void> _handleAddCard() async {
    try {
      final result = await ref
          .read(paymentMutationProvider.notifier)
          .initiateCardLinking();

      final uri = Uri.tryParse(result.paymentUrl);
      if (uri == null) {
        throw ApiException('Некорректная ссылка для привязки карты');
      }

      _awaitingTBankReturn = true;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка привязки карты: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSetDefault(LinkedCardModel card) async {
    if (card.isDefault) return;
    try {
      await ref.read(paymentMutationProvider.notifier).setDefaultCard(card.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Карта •••• ${card.lastFour} выбрана основной'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmUnlink(LinkedCardModel card) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Отвязать карту?'),
        content: Text(
          'Карта ${card.cardMask} будет удалена из вашего профиля.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(paymentMutationProvider.notifier)
                    .unlinkCard(card.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Карта успешно отвязана'),
                    backgroundColor: Colors.green,
                  ),
                );
              } on ApiException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Отвязать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(linkedCardsProvider);
    final isMutating = ref.watch(paymentMutationProvider);

    final screenTitle = widget.isWorkerPayoutMode
        ? 'Карты для выплат'
        : 'Банковские карты';

    final infoBannerText = widget.isWorkerPayoutMode
        ? 'На основную карту автоматически поступают выплаты по Безопасной сделке сразу после оплаты заказа клиентом.'
        : 'Привязанная карта используется для быстрой оплаты заказов через Безопасную сделку Т-Банка.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          screenTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.refresh_cw,
              size: 18,
              color: Color(0xFF0F172A),
            ),
            tooltip: 'Синхронизировать с Т-Банком',
            onPressed: isMutating
                ? null
                : () => ref.invalidate(linkedCardsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF0F172A),
              onRefresh: () async {
                ref.invalidate(linkedCardsProvider);
                await ref.read(linkedCardsProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  // Security & T-Bank Nominal Account Notice
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.shield_check,
                            size: 18,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            infoBannerText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  cardsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.circle_alert,
                            color: Colors.red,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Ошибка загрузки карт: $err',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.invalidate(linkedCardsProvider),
                            icon: const Icon(LucideIcons.refresh_cw, size: 15),
                            label: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                    data: (cards) {
                      if (cards.isEmpty) {
                        return _buildEmptyState();
                      }

                      return Column(
                        children: cards
                            .map(
                              (card) => _CardTile(
                                card: card,
                                isDisabled: isMutating,
                                onSetDefault: () => _handleSetDefault(card),
                                onUnlink: () => _confirmUnlink(card),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Sticky Bottom "Link New Card" Button
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.paddingOf(context).bottom + 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isMutating ? null : _handleAddCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: isMutating
                    ? const SizedBox.shrink()
                    : const Icon(LucideIcons.plus, size: 20),
                label: isMutating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Привязать новую карту',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.credit_card,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет привязанных карт',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isWorkerPayoutMode
                ? 'Привяжите карту любого российского банка, чтобы получать выплаты автоматически.'
                : 'Привяжите карту для быстрой и безопасной оплаты заказов.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final LinkedCardModel card;
  final bool isDisabled;
  final VoidCallback onSetDefault;
  final VoidCallback onUnlink;

  const _CardTile({
    required this.card,
    required this.isDisabled,
    required this.onSetDefault,
    required this.onUnlink,
  });

  Color _brandColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'MIR':
        return const Color(0xFF16A34A);
      case 'VISA':
        return const Color(0xFF1D4ED8);
      case 'MASTERCARD':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF0F172A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = _brandColor(card.cardType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: card.isDefault
              ? const Color(0xFF0F172A)
              : const Color(0xFFE2E8F0),
          width: card.isDefault ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand badge
          Container(
            width: 48,
            height: 36,
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              card.cardType ?? 'CARD',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: brandColor,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Masked PAN, Expiry, Default Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      card.cardMask,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (card.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Основная',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (card.formattedExpDate.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Действует до ${card.formattedExpDate}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action menu (Set Default / Unlink)
          PopupMenuButton<String>(
            enabled: !isDisabled,
            icon: const Icon(
              LucideIcons.ellipsis_vertical,
              size: 18,
              color: Color(0xFF64748B),
            ),
            onSelected: (value) {
              if (value == 'default') onSetDefault();
              if (value == 'unlink') onUnlink();
            },
            itemBuilder: (_) => [
              if (!card.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(
                    children: [
                      Icon(LucideIcons.star, size: 16),
                      SizedBox(width: 8),
                      Text('Сделать основной'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'unlink',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Отвязать', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
