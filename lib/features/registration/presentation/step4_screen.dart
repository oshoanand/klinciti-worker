import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  final _bankNameController = TextEditingController();
  final _bankBikController = TextEditingController();
  final _checkingAccountController = TextEditingController();
  final _correspondentAccountController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill from Riverpod state if available
    final state = ref.read(registrationProvider);
    if (state.bankName != null) _bankNameController.text = state.bankName!;
    if (state.bankBik != null) _bankBikController.text = state.bankBik!;
    if (state.checkingAccount != null) {
      _checkingAccountController.text = state.checkingAccount!;
    }
    if (state.correspondentAccount != null) {
      _correspondentAccountController.text = state.correspondentAccount!;
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankBikController.dispose();
    _checkingAccountController.dispose();
    _correspondentAccountController.dispose();
    super.dispose();
  }

  // ==========================================
  // SUBMIT HANDLER
  // ==========================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // 1. Save data to local Riverpod state
      ref
          .read(registrationProvider.notifier)
          .updateStep4(
            bankName: _bankNameController.text.trim(),
            bankBik: _bankBikController.text.trim(),
            checkingAccount: _checkingAccountController.text.trim(),
            correspondentAccount: _correspondentAccountController.text.trim(),
          );

      // 2. Submit to backend API
      await ref.read(registrationProvider.notifier).submitStep4ToServer();

      if (!mounted) return;

      // 3. Update the global current user state to reflect PENDING moderation
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'moderationStatus': 'PENDING',
          'onboardingStep': 5,
        };
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Регистрация успешно завершена! Анкета отправлена на проверку.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to the Pending Review screen
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

  // ==========================================
  // UI BUILDERS
  // ==========================================
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine context based on the legalType chosen in Step 2
    final state = ref.read(registrationProvider);
    final isOOO = state.legalType == LegalType.ooo;
    final isSelfEmployed = state.legalType == LegalType.selfEmployed;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Реквизиты (Шаг 4/4)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left, color: Color(0xFF0F172A)),
          tooltip: 'Назад к шагу 3',
          onPressed: _isSubmitting
              ? null
              : () => context.go(AppRoutes.workerStep3),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Educational / Info Banner
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
                        isOOO
                            ? 'Введите расчетный счет вашей компании. Платформа Klinciti производит B2B выплаты только на счета банков РФ в рублях.'
                            : (isSelfEmployed
                                  ? 'Укажите реквизиты вашего счета. Для самозанятых (НПД) необходим расчетный или лицевой счет в российском банке.'
                                  : 'Укажите расчетный счет ИП для перечисления безналичных выплат от платформы.'),
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
                'Банковские реквизиты',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Укажите полные реквизиты в соответствии со справкой из банка.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _bankNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  label: 'Название банка *',
                  hint: 'Например: ПАО Сбербанк',
                  icon: LucideIcons.landmark,
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Укажите название банка'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _bankBikController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 9,
                decoration: _inputDecoration(
                  label: 'БИК банка *',
                  hint: '9 цифр',
                  icon: LucideIcons.hash,
                ).copyWith(counterText: ''),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Введите БИК';
                  if (val.length != 9) {
                    return 'БИК должен содержать ровно 9 цифр';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _checkingAccountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 20,
                decoration: _inputDecoration(
                  label: isOOO || !isSelfEmployed
                      ? 'Расчетный счет (р/с) *'
                      : 'Расчетный или лицевой счет *',
                  hint: '20 цифр (начинается с 408 или 407)',
                  icon: LucideIcons.wallet,
                ).copyWith(counterText: ''),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Введите номер счета';
                  }
                  if (val.length != 20) {
                    return 'Номер счета должен содержать ровно 20 цифр';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _correspondentAccountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 20,
                decoration: _inputDecoration(
                  label: 'Корреспондентский счет (к/с) *',
                  hint: '20 цифр (начинается с 301)',
                  icon: LucideIcons.arrow_right_left,
                ).copyWith(counterText: ''),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Введите корр. счет банка';
                  }
                  if (val.length != 20) {
                    return 'Корр. счет должен содержать ровно 20 цифр';
                  }
                  return null;
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.triangle_alert, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                      : const Text(
                          'Завершить регистрацию',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Нажимая «Завершить», вы соглашаетесь с условиями оферты и правилами платформы.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
