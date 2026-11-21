import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/registration_provider.dart';

class PendingReviewScreen extends ConsumerStatefulWidget {
  const PendingReviewScreen({super.key});

  @override
  ConsumerState<PendingReviewScreen> createState() =>
      _PendingReviewScreenState();
}

class _PendingReviewScreenState extends ConsumerState<PendingReviewScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final status = await ref.read(registrationApiProvider).checkStatus();
      if (!mounted) return;

      final modStatus =
          (status['moderationStatus'] ?? status['moderation_status'])
              ?.toString()
              .toUpperCase();
      final rejectionReason =
          (status['rejectionReason'] ?? status['rejection_reason'])?.toString();

      // Sync local user state so app_router.dart redirect guard has the latest status
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null && modStatus != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'moderationStatus': modStatus,
          if (modStatus == 'APPROVED') 'auth_status': 'ACTIVE',
          if (rejectionReason != null) 'rejectionReason': rejectionReason,
        };
      }

      if (modStatus == 'APPROVED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ваш профиль подтвержден! Добро пожаловать.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go(AppRoutes.home);
      } else if (modStatus == 'REJECTED') {
        context.go(AppRoutes.workerRejected, extra: rejectionReason);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ваша анкета все еще находится на проверке'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось проверить статус. Попробуйте позже.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Проверка профиля',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Выйти из аккаунта',
            icon: const Icon(LucideIcons.log_out, color: Colors.red),
            onPressed: () => ref.read(authControllerProvider).logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.clock,
                    size: 48,
                    color: Colors.orange.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Анкета на модерации',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Мы проверяем ваши документы. Обычно это занимает от 1 до 24 часов. Мы пришлем push-уведомление, как только аккаунт будет активирован.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.refresh_cw, size: 18),
                  label: Text(
                    _isChecking ? 'Проверяем...' : 'Обновить статус',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.support),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(LucideIcons.headphones, size: 18),
                  label: const Text(
                    'Написать в поддержку',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
