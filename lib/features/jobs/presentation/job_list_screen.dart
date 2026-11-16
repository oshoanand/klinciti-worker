import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../shared/widgets/global_error_widget.dart';
import '../data/job_model.dart';
import '../providers/job_provider.dart';
import '../../../core/router/route_names.dart';

class JobListScreen extends ConsumerWidget {
  final String status;

  const JobListScreen({super.key, required this.status});

  String _normalizeStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'INCOMING':
      case 'ACCEPTED':
        return 'ACCEPTED';
      case 'ONGOING':
        return 'ONGOING';
      case 'COMPLETED':
        return 'COMPLETED';
      case 'DISPUTED':
        return 'DISPUTED';
      case 'REJECTED':
      case 'REFUSED':
        return 'REFUSED';
      case 'CANCELLED':
        return 'CANCELLED';
      case 'PAYMENT_PENDING':
        return 'PAYMENT_PENDING';
      case 'PAID':
        return 'PAID';
      default:
        return 'ACCEPTED';
    }
  }

  String _getTitle(String normalized) {
    switch (normalized) {
      case 'ACCEPTED':
        return 'Входящие запросы';
      case 'ONGOING':
        return 'Заказы в работе';
      case 'COMPLETED':
        return 'Выполненные заказы';
      case 'PAYMENT_PENDING':
        return 'Ожидают оплаты';
      case 'PAID':
        return 'Оплаченные заказы';
      case 'DISPUTED':
        return 'Спорные ситуации';
      case 'REFUSED':
        return 'Отклоненные заказы';
      case 'CANCELLED':
        return 'Отмененные заказы';
      default:
        return 'Задания';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedStatus = _normalizeStatus(status);
    final jobsAsync = ref.watch(jobsByStatusProvider(normalizedStatus));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _getTitle(normalizedStatus),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(jobsByStatusProvider(normalizedStatus).future),
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => GlobalErrorWidget(
            message: ApiException.fromDioException(err).message,
            onRetry: () =>
                ref.refresh(jobsByStatusProvider(normalizedStatus).future),
          ),
          data: (paginated) {
            final jobs = paginated.jobs;

            if (jobs.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.folder_open,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'В этой категории пока нет заданий',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _JobCard(
                  job: job,

                  onTap: () => context.push('${AppRoutes.jobDetail}/${job.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = job.createdAt != null
        ? '${job.createdAt!.day.toString().padLeft(2, '0')}.${job.createdAt!.month.toString().padLeft(2, '0')}.${job.createdAt!.year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job.displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${job.budget.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              if (job.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  job.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.map_pin, size: 15, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${job.city.isNotEmpty ? '${job.city}, ' : ''}${job.pickupAddress}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
