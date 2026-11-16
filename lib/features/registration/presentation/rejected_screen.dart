import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/registration_provider.dart';

class RejectedScreen extends ConsumerStatefulWidget {
  final String? initialReason;

  const RejectedScreen({super.key, this.initialReason});

  @override
  ConsumerState<RejectedScreen> createState() => _RejectedScreenState();
}

class _RejectedScreenState extends ConsumerState<RejectedScreen> {
  String? _rejectionReason;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rejectionReason = widget.initialReason;
    if (_rejectionReason == null || _rejectionReason!.trim().isEmpty) {
      // Also check if reason is already cached in currentUserProvider
      final cachedUser = ref.read(currentUserProvider);
      final cachedReason =
          (cachedUser?['rejectionReason'] ?? cachedUser?['rejection_reason'])
              ?.toString();
      if (cachedReason != null && cachedReason.trim().isNotEmpty) {
        _rejectionReason = cachedReason;
      } else {
        _fetchLatestReason();
      }
    }
  }

  Future<void> _fetchLatestReason() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final status = await ref.read(registrationProvider).checkStatus();
      if (!mounted) return;

      final modStatus =
          (status['moderationStatus'] ?? status['moderation_status'])
              ?.toString()
              .toUpperCase();
      final fetchedReason =
          (status['rejectionReason'] ?? status['rejection_reason'])?.toString();

      // ✅ Sync local user state so app_router.dart redirect guard stays in sync
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null && modStatus != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'moderationStatus': modStatus,
          if (modStatus == 'APPROVED') 'auth_status': 'ACTIVE',
          if (fetchedReason != null) 'rejectionReason': fetchedReason,
        };
      }

      if (modStatus == 'APPROVED') {
        context.go(AppRoutes.home);
        return;
      } else if (modStatus == 'PENDING') {
        context.go(AppRoutes.workerPendingReview);
        return;
      }

      setState(() {
        _rejectionReason = fetchedReason;
      });
    } catch (_) {
      // Fallback to default message if request fails
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startCorrection(String targetRoute, {required int step}) {
    // ✅ Update local user state to INCOMPLETE + target step so router allows navigation
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref.read(currentUserProvider.notifier).state = {
        ...currentUser,
        'moderationStatus': 'INCOMPLETE',
        'onboardingStep': step,
      };
    }
    context.go(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    final reasonText =
        (_rejectionReason != null && _rejectionReason!.trim().isNotEmpty)
        ? _rejectionReason!.trim()
        : 'Модератор обнаружил неточности в анкете или нечеткие фотографии документов. Пожалуйста, проверьте данные и отправьте анкету повторно.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Статус анкеты',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refresh_cw, color: Color(0xFF0F172A)),
            tooltip: 'Обновить статус',
            onPressed: _isLoading ? null : _fetchLatestReason,
          ),
          IconButton(
            icon: const Icon(LucideIcons.log_out, color: Colors.red),
            tooltip: 'Выйти из аккаунта',
            onPressed: () => ref.read(authControllerProvider).logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(),
                            Center(
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.circle_alert,
                                  size: 48,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Анкета отклонена',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Исправьте указанные замечания и отправьте заявку на повторную проверку.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Moderator Rejection Reason Box
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.message_square_warning,
                                        size: 18,
                                        color: Colors.red.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Комментарий модератора:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    reasonText,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      color: Colors.red.shade900,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 24),

                            // Primary Action: Fix KYC Documents directly (Step 3)
                            SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () => _startCorrection(
                                  AppRoutes.workerStep3,
                                  step: 3,
                                ),
                                icon: const Icon(LucideIcons.camera, size: 18),
                                label: const Text(
                                  'Переснять документы (Шаг 3)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Secondary Action: Edit full profile starting from Step 2
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: () => _startCorrection(
                                  AppRoutes.workerStep2,
                                  step: 2,
                                ),
                                icon: const Icon(
                                  LucideIcons.file_pen,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Редактировать анкету с начала (Шаг 2)',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Support Chat Shortcut
                            TextButton.icon(
                              onPressed: () => context.push(AppRoutes.support),
                              icon: const Icon(
                                LucideIcons.headphones,
                                size: 16,
                              ),
                              label: const Text('Связаться с поддержкой'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
