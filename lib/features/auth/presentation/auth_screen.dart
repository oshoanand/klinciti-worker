import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';

enum AuthMode { login, register, forgotPassword, verifyOtp, resetPassword }

enum IdentifierInputType { phone, email }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // State
  AuthMode _mode = AuthMode.login;
  IdentifierInputType _inputType = IdentifierInputType.phone;

  // ✅ Strictly 'AUTH', 'REGISTER', or 'RESET' to match backend Zod enum
  String _otpContext = 'AUTH';

  // ✅ Preserves the normalized identifier across form resets when switching to VerifyOtp
  String _activeIdentifier = '';

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  String? _errorMessage;

  // 50-Second Resend OTP Timer
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;
  bool _isResendingOtp = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _idController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // ==========================================
  // 50-SECOND OTP TIMER LOGIC
  // ==========================================
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsRemaining = 50;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining -= 1);
      }
    });
  }

  void _switchMode(AuthMode newMode) {
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = newMode;
      _errorMessage = null;
      if (newMode == AuthMode.verifyOtp) {
        _otpController.clear();
      }
    });
    if (newMode == AuthMode.verifyOtp) {
      _startResendTimer();
    } else {
      _resendTimer?.cancel();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  // ==========================================
  // VALIDATORS
  // ==========================================
  String? _validateIdentifier(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _inputType == IdentifierInputType.phone
          ? 'Введите номер телефона'
          : 'Введите адрес электронной почты';
    }

    if (_inputType == IdentifierInputType.email || text.contains('@')) {
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(text)) {
        return 'Введите корректный Email (например: name@mail.ru)';
      }
      return null;
    } else {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 10) return null; // Will be prefixed with 7
      if (digits.length == 11 &&
          (digits.startsWith('7') || digits.startsWith('8'))) {
        return null;
      }
      return 'Введите 11 цифр номера (начинается с 7 или 8)';
    }
  }

  String? _validatePassword(String? value, {bool isRegistration = false}) {
    final text = value ?? '';
    if (text.isEmpty) return 'Введите пароль';
    if (isRegistration && text.length < 6) {
      return 'Пароль должен содержать минимум 6 символов';
    }
    return null;
  }

  String? _validateName(String? value, String fieldLabel) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Укажите $fieldLabel';
    if (text.length < 2) return 'Минимум 2 символа';
    return null;
  }

  String? _validateOtp(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Введите код из сообщения';
    if (text.length < 4) return 'Код должен содержать минимум 4 цифры';
    return null;
  }

  // ==========================================
  // NAVIGATION ROUTING LOGIC
  // ==========================================
  void _routeAuthenticatedUser() {
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final modStatus = user['moderationStatus']?.toString() ?? 'INCOMPLETE';
    final authStatus = user['auth_status']?.toString() ?? 'PENDING';

    if (modStatus == 'INCOMPLETE' ||
        modStatus == 'PENDING' ||
        modStatus == 'REJECTED' ||
        authStatus == 'PENDING' ||
        authStatus == 'BLOCKED') {
      context.go(AppRoutes.workerResolve);
    } else {
      context.go(AppRoutes.home);
    }
  }

  // ==========================================
  // ACTION HANDLERS
  // ==========================================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authCtrl = ref.read(authControllerProvider);
    final normalized = authCtrl.normalizeIdentifier(_idController.text);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeIdentifier = normalized;
    });

    try {
      final success = await authCtrl.login(
        normalized,
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        _routeAuthenticatedUser();
      } else {
        setState(() {
          _otpContext = 'AUTH'; // ✅ Matches backend Zod enum
          _isLoading = false;
        });
        _switchMode(AuthMode.verifyOtp);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Неожиданная ошибка. Попробуйте позже.');
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final authCtrl = ref.read(authControllerProvider);
    final normalized = authCtrl.normalizeIdentifier(_idController.text);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeIdentifier = normalized;
    });

    try {
      await authCtrl.register(
        identifier: normalized,
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _otpContext = 'REGISTER';
        _isLoading = false;
      });
      _switchMode(AuthMode.verifyOtp);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Ошибка при регистрации. Проверьте данные.');
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final targetId = _activeIdentifier.isNotEmpty
        ? _activeIdentifier
        : ref
              .read(authControllerProvider)
              .normalizeIdentifier(_idController.text);

    if (targetId.isEmpty) {
      _showError('Не удалось определить номер телефона или Email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .verifyOtp(targetId, _otpController.text.trim(), _otpContext);

      if (!mounted) return;

      if (_otpContext == 'RESET') {
        setState(() => _isLoading = false);
        _switchMode(AuthMode.resetPassword);
      } else {
        _routeAuthenticatedUser();
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Неверный или просроченный код подтверждения.');
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendSecondsRemaining > 0 || _isResendingOtp) return;

    final targetId = _activeIdentifier.isNotEmpty
        ? _activeIdentifier
        : ref
              .read(authControllerProvider)
              .normalizeIdentifier(_idController.text);

    setState(() {
      _isResendingOtp = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .resendOtp(identifier: targetId, contextStr: _otpContext);

      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Новый код подтверждения отправлен'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Не удалось отправить код повторно');
    } finally {
      if (mounted) {
        setState(() => _isResendingOtp = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final authCtrl = ref.read(authControllerProvider);
    final normalized = authCtrl.normalizeIdentifier(_idController.text);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeIdentifier = normalized;
    });

    try {
      await authCtrl.forgotPassword(normalized);
      if (!mounted) return;

      setState(() {
        _otpContext = 'RESET';
        _isLoading = false;
      });
      _switchMode(AuthMode.verifyOtp);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Не удалось отправить код восстановления');
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final targetId = _activeIdentifier.isNotEmpty
        ? _activeIdentifier
        : ref
              .read(authControllerProvider)
              .normalizeIdentifier(_idController.text);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .resetPassword(
            targetId,
            _otpController.text.trim(),
            _newPasswordController.text,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль успешно изменен. Войдите в аккаунт.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _passwordController.clear();
      setState(() => _isLoading = false);
      _switchMode(AuthMode.login);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Не удалось сохранить новый пароль');
    }
  }

  // ==========================================
  // INPUT DECORATION HELPER
  // ==========================================
  InputDecoration _modernInputDecoration({
    required String label,
    String? hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
      ),
    );
  }

  // ==========================================
  // SEGMENTED PHONE / EMAIL TOGGLE
  // ==========================================
  Widget _buildIdentifierTypeToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_inputType != IdentifierInputType.phone) {
                  setState(() {
                    _inputType = IdentifierInputType.phone;
                    _idController.clear();
                    _errorMessage = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _inputType == IdentifierInputType.phone
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _inputType == IdentifierInputType.phone
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.phone,
                      size: 16,
                      color: _inputType == IdentifierInputType.phone
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Телефон',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: _inputType == IdentifierInputType.phone
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_inputType != IdentifierInputType.email) {
                  setState(() {
                    _inputType = IdentifierInputType.email;
                    _idController.clear();
                    _errorMessage = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _inputType == IdentifierInputType.email
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _inputType == IdentifierInputType.email
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.mail,
                      size: 16,
                      color: _inputType == IdentifierInputType.email
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Email',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: _inputType == IdentifierInputType.email
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentifierField() {
    final isPhone = _inputType == IdentifierInputType.phone;
    return TextFormField(
      controller: _idController,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      inputFormatters: isPhone
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\-() ]')),
              LengthLimitingTextInputFormatter(18),
            ]
          : null,
      decoration: _modernInputDecoration(
        label: isPhone ? 'Номер телефона' : 'Электронная почта',
        hint: isPhone ? '79991234567' : 'partner@example.com',
        prefixIcon: isPhone ? LucideIcons.phone : LucideIcons.mail,
      ),
      validator: _validateIdentifier,
    );
  }

  // ==========================================
  // UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _mode != AuthMode.login
            ? IconButton(
                icon: const Icon(
                  LucideIcons.arrow_left,
                  color: Color(0xFF0F172A),
                ),
                onPressed: () => _switchMode(AuthMode.login),
              )
            : (context.canPop()
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, color: Color(0xFF0F172A)),
                      onPressed: () => context.pop(),
                    )
                  : null),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon & Title
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getHeaderIcon(),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _getAppBarTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getSubtitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Main White Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFormContent(),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.circle_alert,
                                  color: Color(0xFFDC2626),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Primary Submit CTA
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _getSubmitAction(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF94A3B8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _getSubmitButtonText(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                _buildBottomLinks(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getHeaderIcon() {
    switch (_mode) {
      case AuthMode.login:
        return LucideIcons.briefcase;
      case AuthMode.register:
        return LucideIcons.user_plus;
      case AuthMode.verifyOtp:
        return LucideIcons.shield_check;
      case AuthMode.forgotPassword:
        return LucideIcons.key_round;
      case AuthMode.resetPassword:
        return LucideIcons.lock_keyhole;
    }
  }

  String _getAppBarTitle() {
    switch (_mode) {
      case AuthMode.login:
        return 'Вход для партнеров';
      case AuthMode.register:
        return 'Регистрация мастера';
      case AuthMode.verifyOtp:
        return 'Подтверждение кода';
      case AuthMode.forgotPassword:
        return 'Восстановление доступа';
      case AuthMode.resetPassword:
        return 'Новый пароль';
    }
  }

  String _getSubtitle() {
    switch (_mode) {
      case AuthMode.login:
        return 'Войдите в кабинет исполнителя для управления заказами';
      case AuthMode.register:
        return 'Создайте профиль партнера за пару минут и начните зарабатывать';
      case AuthMode.verifyOtp:
        final displayTarget = _activeIdentifier.isNotEmpty
            ? _activeIdentifier
            : _idController.text.trim();
        return 'Мы отправили проверочный код на\n$displayTarget';
      case AuthMode.forgotPassword:
        return 'Укажите ваш телефон или Email для получения кода сброса пароля';
      case AuthMode.resetPassword:
        return 'Придумайте надежный пароль минимум из 6 символов';
    }
  }

  VoidCallback _getSubmitAction() {
    switch (_mode) {
      case AuthMode.login:
        return _handleLogin;
      case AuthMode.register:
        return _handleRegister;
      case AuthMode.verifyOtp:
        return _handleVerifyOtp;
      case AuthMode.forgotPassword:
        return _handleForgotPassword;
      case AuthMode.resetPassword:
        return _handleResetPassword;
    }
  }

  String _getSubmitButtonText() {
    switch (_mode) {
      case AuthMode.login:
        return 'Войти в аккаунт';
      case AuthMode.register:
        return 'Создать аккаунт';
      case AuthMode.verifyOtp:
        return 'Подтвердить код';
      case AuthMode.forgotPassword:
        return 'Получить код';
      case AuthMode.resetPassword:
        return 'Сохранить пароль';
    }
  }

  Widget _buildFormContent() {
    switch (_mode) {
      case AuthMode.login:
        return Column(
          children: [
            _buildIdentifierTypeToggle(),
            _buildIdentifierField(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: _modernInputDecoration(
                label: 'Пароль',
                hint: 'Введите ваш пароль',
                prefixIcon: LucideIcons.lock,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eye_off : LucideIcons.eye,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => _validatePassword(v, isRegistration: false),
            ),
          ],
        );

      case AuthMode.register:
        return Column(
          children: [
            _buildIdentifierTypeToggle(),
            TextFormField(
              controller: _firstNameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _modernInputDecoration(
                label: 'Имя *',
                hint: 'Иван',
                prefixIcon: LucideIcons.user,
              ),
              validator: (v) => _validateName(v, 'имя'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastNameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _modernInputDecoration(
                label: 'Фамилия *',
                hint: 'Иванов',
                prefixIcon: LucideIcons.user_check,
              ),
              validator: (v) => _validateName(v, 'фамилию'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _middleNameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _modernInputDecoration(
                label: 'Отчество (необязательно)',
                hint: 'Иванович',
                prefixIcon: LucideIcons.badge_info,
              ),
            ),
            const SizedBox(height: 14),
            _buildIdentifierField(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              decoration: _modernInputDecoration(
                label: 'Пароль (мин. 6 символов) *',
                hint: '••••••••',
                prefixIcon: LucideIcons.lock,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eye_off : LucideIcons.eye,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => _validatePassword(v, isRegistration: true),
            ),
          ],
        );

      case AuthMode.verifyOtp:
        return Column(
          children: [
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Color(0xFF0F172A),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => _handleVerifyOtp(),
              decoration: _modernInputDecoration(
                label: 'Код подтверждения',
                hint: '••••••',
                prefixIcon: LucideIcons.key_round,
              ).copyWith(counterText: ''),
              validator: _validateOtp,
            ),
            const SizedBox(height: 16),

            // 50-Second Countdown & Resend Button
            if (_resendSecondsRemaining > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.clock,
                    size: 15,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Повторная отправка через ${_resendSecondsRemaining} сек.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: _isResendingOtp ? null : _handleResendOtp,
                icon: _isResendingOtp
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.refresh_cw, size: 15),
                label: const Text(
                  'Отправить код повторно',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );

      case AuthMode.forgotPassword:
        return Column(
          children: [_buildIdentifierTypeToggle(), _buildIdentifierField()],
        );

      case AuthMode.resetPassword:
        return TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleResetPassword(),
          decoration: _modernInputDecoration(
            label: 'Новый пароль',
            hint: 'Минимум 6 символов',
            prefixIcon: LucideIcons.lock_keyhole,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? LucideIcons.eye_off : LucideIcons.eye,
                size: 18,
                color: const Color(0xFF64748B),
              ),
              onPressed: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
          ),
          validator: (v) => _validatePassword(v, isRegistration: true),
        );
    }
  }

  Widget _buildBottomLinks() {
    if (_mode == AuthMode.login) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            TextButton(
              onPressed: () => _switchMode(AuthMode.forgotPassword),
              child: const Text(
                'Забыли пароль?',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _switchMode(AuthMode.register),
              icon: const Icon(LucideIcons.user_plus, size: 18),
              label: const Text(
                'Стать партнером (Регистрация)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_mode == AuthMode.register) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: TextButton(
          onPressed: () => _switchMode(AuthMode.login),
          child: const Text(
            'Уже есть аккаунт партнера? Войти',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
