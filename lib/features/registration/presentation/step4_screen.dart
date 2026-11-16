import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/registration_provider.dart';

class Step4Screen extends ConsumerStatefulWidget {
  const Step4Screen({super.key});

  @override
  ConsumerState<Step4Screen> createState() => _Step4ScreenState();
}

class _Step4ScreenState extends ConsumerState<Step4Screen> {
  final _formKey = GlobalKey<FormState>();
  final _taxIdController = TextEditingController();
  final _payoutController = TextEditingController();

  bool _isLoadingExisting = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isAlreadyApproved {
    final user = ref.read(currentUserProvider);
    final status = (user?['moderationStatus'] ?? user?['moderation_status'])
        ?.toString()
        .toUpperCase();
    return status == 'APPROVED';
  }

  @override
  void initState() {
    super.initState();
    _loadExistingFinancialsIfNeeded();
  }

  /// Pre-fills existing tax_id and payout_details if the worker already has them saved
  Future<void> _loadExistingFinancialsIfNeeded() async {
    setState(() => _isLoadingExisting = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/workers/profile');
      if (!mounted) return;

      if (res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        final existingTax =
            data['tax_id']?.toString() ?? data['taxId']?.toString() ?? '';
        final existingPayout =
            data['payout_details']?.toString() ??
            data['payoutDetails']?.toString() ??
            '';

        if (existingTax.isNotEmpty && _taxIdController.text.isEmpty) {
          _taxIdController.text = existingTax;
        }
        if (existingPayout.isNotEmpty && _payoutController.text.isEmpty) {
          _payoutController.text = existingPayout;
        }
      }
    } catch (_) {
      // Ignore if profile fetch fails during initial onboarding
    } finally {
      if (mounted) {
        setState(() => _isLoadingExisting = false);
      }
    }
  }

  @override
  void dispose() {
    _taxIdController.dispose();
    _payoutController.dispose();
    super.dispose();
  }

  // ==========================================
  // SUBMIT OR SKIP STEP 4
  // ==========================================
  Future<void> _submit({required bool isSkipping}) async {
    if (!isSkipping && !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final taxId = isSkipping || _taxIdController.text.trim().isEmpty
          ? null
          : _taxIdController.text.trim();

      final payoutDetails = isSkipping || _payoutController.text.trim().isEmpty
          ? null
          : _payoutController.text.trim();

      final payload = <String, dynamic>{
        if (taxId != null) 'taxId': taxId,
        if (payoutDetails != null) 'payoutDetails': payoutDetails,
      };

      await ref.read(registrationProvider).submitStep4(payload);

      if (!mounted) return;

      // ✅ If the worker is already APPROVED, keep them APPROVED and pop back
      if (_isAlreadyApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Платежные реквизиты успешно сохранены'),
            backgroundColor: Colors.green,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
        return;
      }

      // ✅ Otherwise, this is initial Onboarding Step 4 -> Move to PENDING review
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'moderationStatus': 'PENDING',
          'onboardingStep': 4,
        };
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Регистрация завершена. Ваш профиль отправлен на проверку администратору.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      context.go(AppRoutes.workerPendingReview);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка сохранения реквизитов: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApprovedMode = _isAlreadyApproved;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          isApprovedMode ? 'Реквизиты и выплаты' : 'Реквизиты (Шаг 4/4)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left, color: Color(0xFF0F172A)),
          tooltip: isApprovedMode ? 'Назад' : 'Назад к шагу 3',
          onPressed: _isSubmitting
              ? null
              : () {
                  if (isApprovedMode && context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.workerStep3);
                  }
                },
        ),
        actions: [
          if (!isApprovedMode)
            TextButton(
              onPressed: _isSubmitting ? null : () => _submit(isSkipping: true),
              child: const Text(
                'Пропустить',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingExisting
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.info,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isApprovedMode
                                  ? 'Укажите актуальный ИНН и номер карты или телефона СБП, на которые вам удобно получать выплаты за выполненные заказы.'
                                  : 'Этот шаг необязателен. Вы можете пропустить его сейчас и добавить или изменить реквизиты позже в настройках профиля.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Финансовая информация',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Укажите реквизиты для получения выплат за выполненные заказы.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Optional Tax ID (INN)
                    TextFormField(
                      controller: _taxIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: InputDecoration(
                        labelText: 'ИНН (необязательно)',
                        hintText: '10 или 12 цифр',
                        prefixIcon: const Icon(LucideIcons.file_badge),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final clean = v.trim();
                        if (clean.length != 10 && clean.length != 12) {
                          return 'ИНН должен содержать 10 или 12 цифр';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Optional Payout Details (Card / Phone for SBP / Account)
                    TextFormField(
                      controller: _payoutController,
                      maxLines: 3,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Реквизиты для выплат (необязательно)',
                        hintText: 'Номер карты, телефон СБП и название банка (например: Сбербанк / Т-Банк)',
                        prefixIcon: const Icon(LucideIcons.credit_card),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Primary Submit Button
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submit(isSkipping: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isApprovedMode
                              ? const Color(0xFF0F172A)
                              : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isApprovedMode
                                    ? 'Сохранить реквизиты'
                                    : 'Сохранить и отправить на проверку',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    if (!isApprovedMode) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submit(isSkipping: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Заполнить позже в профиле',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
