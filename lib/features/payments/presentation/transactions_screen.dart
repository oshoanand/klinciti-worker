import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/payment_provider.dart';

class WorkerTransactionsScreen extends ConsumerStatefulWidget {
  const WorkerTransactionsScreen({super.key});

  @override
  ConsumerState<WorkerTransactionsScreen> createState() =>
      _WorkerTransactionsScreenState();
}

class _WorkerTransactionsScreenState
    extends ConsumerState<WorkerTransactionsScreen> {
  String _selectedDirection = 'ALL'; // 'ALL' | 'INCOMING' | 'OUTGOING'

  static const List<({String id, String label})> _filters = [
    (id: 'ALL', label: 'Все'),
    (id: 'INCOMING', label: 'Поступления'),
    (id: 'OUTGOING', label: 'Списания'),
  ];

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(workerTransactionsProvider(_selectedDirection));

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
        title: const Text(
          'Транзакции',
          style: TextStyle(
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
            tooltip: 'Обновить',
            onPressed: () => ref
                .read(workerTransactionsProvider(_selectedDirection).notifier)
                .refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar (All / Incoming / Outgoing)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedDirection == filter.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected && _selectedDirection != filter.id) {
                        setState(() => _selectedDirection = filter.id);
                      }
                    },
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF0F172A),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF0F172A),
              onRefresh: () => ref
                  .read(workerTransactionsProvider(_selectedDirection).notifier)
                  .refresh(),
              child: txAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0F172A)),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.circle_alert,
                          color: Colors.red,
                          size: 38,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ошибка загрузки: $err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(
                                workerTransactionsProvider(_selectedDirection)
                                    .notifier,
                              )
                              .refresh(),
                          icon: const Icon(LucideIcons.refresh_cw, size: 15),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (paginated) {
                  if (paginated.items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.arrow_left_right,
                                  size: 36,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Транзакций пока нет',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Здесь будет отображаться история ваших выплат и списаний.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount:
                        paginated.items.length + (paginated.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Bottom "Load More" button
                      if (index == paginated.items.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: paginated.isLoadingMore
                                  ? null
                                  : () => ref
                                        .read(
                                          workerTransactionsProvider(
                                            _selectedDirection,
                                          ).notifier,
                                        )
                                        .loadMore(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: paginated.isLoadingMore
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0F172A),
                                      ),
                                    )
                                  : Text(
                                      'Загрузить ещё (${paginated.items.length} из ${paginated.total})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      }

                      return _TransactionTile(tx: paginated.items[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WorkerTransactionModel tx;

  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isIncoming = tx.isIncoming;
    final accentColor = isIncoming
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final sign = isIncoming ? '+' : '−';
    final dateStr = tx.createdAt != null
        ? DateFormat('dd.MM.yyyy, HH:mm').format(tx.createdAt!.toLocal())
        : '';

    final shortJobId = tx.jobId != null && tx.jobId!.length >= 8
        ? '#${tx.jobId!.substring(0, 8)}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Direction Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncoming
                  ? LucideIcons.arrow_down_left
                  : LucideIcons.arrow_up_right,
              size: 20,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),

          // Title, Job Ref & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (shortJobId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Заказ $shortJobId',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Amount & Status Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${tx.amount.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 6),
              _buildStatusBadge(tx.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'COMPLETED':
      case 'PAID_OUT':
      case 'SUCCEEDED':
      case 'ACCRUED':
        color = Colors.teal;
        label = 'Выполнено';
        break;
      case 'PROCESSING':
      case 'PENDING':
        color = Colors.orange;
        label = 'В обработке';
        break;
      case 'FAILED':
      case 'REJECTED':
        color = Colors.red;
        label = 'Ошибка';
        break;
      default:
        color = Colors.blueGrey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
