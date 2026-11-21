import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/registration_provider.dart';

class OnboardingResolverScreen extends ConsumerStatefulWidget {
  const OnboardingResolverScreen({super.key});

  @override
  ConsumerState<OnboardingResolverScreen> createState() =>
      _OnboardingResolverScreenState();
}

class _OnboardingResolverScreenState
    extends ConsumerState<OnboardingResolverScreen> {
  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _resolveStatus();
  }

  Future<void> _resolveStatus() async {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _errorText = null;
    });

    try {
      final status = await ref.read(registrationApiProvider).checkStatus();
      if (!mounted) return;

      final modStatus =
          (status['moderationStatus'] ?? status['moderation_status'])
              ?.toString()
              .toUpperCase();
      final rejectionReason =
          (status['rejectionReason'] ?? status['rejection_reason'])?.toString();
      final int currentStep =
          int.tryParse(
            (status['currentStep'] ?? status['onboardingStep'] ?? 2).toString(),
          ) ??
          2;

      // Sync local user state so GoRouter redirect guard doesn't loop
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          if (modStatus != null) 'moderationStatus': modStatus,
          'onboardingStep': currentStep,
          if (rejectionReason != null) 'rejectionReason': rejectionReason,
        };
      }

      // ✅ 1. APPROVED -> Send directly to Worker Home Dashboard
      if (modStatus == 'APPROVED') {
        context.go(AppRoutes.home);
        return;
      }

      // ✅ 2. REJECTED -> Send to Rejection Screen with reason
      if (modStatus == 'REJECTED') {
        context.go(AppRoutes.workerRejected, extra: rejectionReason);
        return;
      }

      // ✅ 3. PENDING -> Send to Pending Review Screen
      if (modStatus == 'PENDING') {
        context.go(AppRoutes.workerPendingReview);
        return;
      }

      // ✅ 4. INCOMPLETE ONBOARDING -> Route to exact step
      if (currentStep <= 2) {
        context.go(AppRoutes.workerStep2);
      } else if (currentStep == 3) {
        context.go(AppRoutes.workerStep3);
      } else if (currentStep == 4) {
        context.go(AppRoutes.workerStep4);
      } else {
        context.go(AppRoutes.workerPendingReview);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorText =
            'Не удалось загрузить статус анкеты. Проверьте соединение.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: _hasError
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.wifi_off,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorText ?? 'Ошибка подключения',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _resolveStatus,
                        icon: const Icon(LucideIcons.refresh_cw, size: 16),
                        label: const Text('Повторить'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            ref.read(authControllerProvider).logout(context),
                        child: const Text(
                          'Выйти из аккаунта',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0F172A)),
                    SizedBox(height: 16),
                    Text(
                      'Проверяем статус профиля...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
