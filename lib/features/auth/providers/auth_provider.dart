import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/router/route_names.dart';
import '../../../core/socket/socket_service.dart';

typedef UserMap = Map<String, dynamic>;
// ==========================================
// 1. GLOBAL AUTH STATE
// ==========================================
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);
final currentUserProvider = StateProvider<UserMap?>((ref) => null);

// ==========================================
// 2. AUTH CONTROLLER PROVIDER
// ==========================================
final authControllerProvider = Provider<AuthController>((ref) {
  final controller = AuthController(ref.watch(apiClientProvider), ref);

  // Automatically persist any in-memory updates to `currentUserProvider`
  // (e.g. when OnboardingResolverScreen, Step2-4, or ProfileEditScreen updates user fields)
  ref.listen(currentUserProvider, (previous, next) {
    if (next != null) {
      controller.persistUserDataSilently(next);
    }
  });

  return controller;
});

// ==========================================
// 3. AUTH CONTROLLER IMPLEMENTATION
// ==========================================
class AuthController {
  final ApiClient _api;
  final Ref _ref;

  AuthController(this._api, this._ref);

  Future<void> persistUserDataSilently(Map<String, dynamic> userData) async {
    try {
      await _api.storage.write(key: 'user_data', value: jsonEncode(userData));
    } catch (_) {}
  }

  /// Normalizes phone numbers to 11 digits starting with 7 and trims emails
  /// so backend Zod validation never fails on spaces, '+', or parentheses.
  String normalizeIdentifier(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }
    String digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      digits = '7$digits';
    } else if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    return digits;
  }

  /// Normalizes OTP context to strictly match backend enum: 'AUTH' | 'REGISTER' | 'RESET'
  String _normalizeOtpContext(String contextStr) {
    final upper = contextStr.trim().toUpperCase();
    if (upper == 'LOGIN' || upper == 'AUTH') return 'AUTH';
    if (upper == 'REGISTER') return 'REGISTER';
    if (upper == 'RESET') return 'RESET';
    return 'AUTH';
  }

  /// Syncs live worker moderationStatus and onboardingStep from `/workers/onboarding/status`
  Future<UserMap> _syncWorkerStatusIfPossible(UserMap baseUser) async {
    try {
      final res = await _api.dio.get('/workers/onboarding/status');
      if (res.data is Map) {
        final statusData = Map<String, dynamic>.from(res.data as Map);
        final modStatus =
            (statusData['moderationStatus'] ?? statusData['moderation_status'])
                ?.toString();
        final step = statusData['currentStep'] ?? statusData['onboardingStep'];
        final reason =
            statusData['rejectionReason'] ?? statusData['rejection_reason'];

        return {
          ...baseUser,
          if (modStatus != null) 'moderationStatus': modStatus,
          if (step != null) 'onboardingStep': step,
          if (reason != null) 'rejectionReason': reason,
        };
      }
    } catch (e) {
      log('Worker status sync skipped: $e');
    }
    return baseUser;
  }

  Future<void> checkInitialAuth() async {
    try {
      final token = await _api.storage.read(key: 'jwt_token');
      final userId = await _api.storage.read(key: 'user_id');
      final userDataStr = await _api.storage.read(key: 'user_data');

      if (token != null &&
          token.isNotEmpty &&
          userId != null &&
          userDataStr != null) {
        var userData = Map<String, dynamic>.from(
          jsonDecode(userDataStr) as Map,
        );

        // Set initial cached state immediately
        _ref.read(currentUserProvider.notifier).state = userData;
        _ref.read(isAuthenticatedProvider.notifier).state = true;

        // Refresh live moderationStatus from backend so approved/rejected changes apply on startup
        userData = await _syncWorkerStatusIfPossible(userData);
        _ref.read(currentUserProvider.notifier).state = userData;

        try {
          final mobile = userData['mobile']?.toString();
          final notifService = _ref.read(notificationServiceProvider);

          await notifService.registerTokenAfterLogin();
          await notifService.subscribeToUserTopics(mobile);
          await _ref.read(socketServiceProvider).connect(userId);
        } catch (e) {
          log('FCM/Socket Setup Error (Ignored): $e');
        }
      } else {
        _ref.read(isAuthenticatedProvider.notifier).state = false;
        _ref.read(currentUserProvider.notifier).state = null;
      }
    } catch (e) {
      _ref.read(isAuthenticatedProvider.notifier).state = false;
      _ref.read(currentUserProvider.notifier).state = null;
    }
  }

  // =======================================================
  // LOGIN FLOW
  // Returns TRUE if logged in, FALSE if OTP verification is required
  // =======================================================
  Future<bool> login(String identifier, String password) async {
    try {
      final cleanId = normalizeIdentifier(identifier);
      final response = await _api.dio.post(
        '/auth/login',
        data: {'identifier': cleanId, 'password': password},
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      if (data['needsVerification'] == true) {
        return false;
      }

      await saveSession(data);
      return true;
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // =======================================================
  // REGISTRATION FLOW (Step 1)
  // =======================================================
  Future<void> register({
    required String identifier,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
  }) async {
    try {
      final cleanId = normalizeIdentifier(identifier);
      await _api.dio.post(
        '/auth/register',
        data: {
          'identifier': cleanId,
          'password': password,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          if (middleName != null && middleName.trim().isNotEmpty)
            'middleName': middleName.trim(),
          'role': 'WORKER',
          'termsAccepted': true,
        },
      );
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // =======================================================
  // OTP VERIFICATION
  // Backend expects context: 'AUTH' | 'REGISTER' | 'RESET'
  // =======================================================
  Future<void> verifyOtp(
    String identifier,
    String otp,
    String contextStr,
  ) async {
    try {
      final cleanId = normalizeIdentifier(identifier);
      final validContext = _normalizeOtpContext(contextStr);

      final response = await _api.dio.post(
        '/auth/verify-otp',
        data: {
          'identifier': cleanId,
          'otp': otp.trim(),
          'context': validContext,
        },
      );

      if (validContext == 'RESET') {
        return;
      }

      final data = Map<String, dynamic>.from(response.data as Map);
      await saveSession(data);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // =======================================================
  // RESEND OTP
  // =======================================================
  Future<void> resendOtp({
    required String identifier,
    required String contextStr,
  }) async {
    try {
      final cleanId = normalizeIdentifier(identifier);
      final validContext = _normalizeOtpContext(contextStr);

      if (validContext == 'RESET') {
        await _api.dio.post(
          '/auth/forgot-password',
          data: {'identifier': cleanId},
        );
      } else {
        await _api.dio.post(
          '/auth/resend-otp',
          data: {'identifier': cleanId, 'context': validContext},
        );
      }
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // =======================================================
  // PASSWORD RECOVERY
  // =======================================================
  Future<void> forgotPassword(String identifier) async {
    try {
      final cleanId = normalizeIdentifier(identifier);
      await _api.dio.post(
        '/auth/forgot-password',
        data: {'identifier': cleanId},
      );
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> resetPassword(
    String identifier,
    String otp,
    String newPassword,
  ) async {
    try {
      final cleanId = normalizeIdentifier(identifier);
      await _api.dio.post(
        '/auth/reset-password',
        data: {
          'identifier': cleanId,
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
      );
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // =======================================================
  // SESSION MANAGEMENT
  // =======================================================
  Future<void> saveSession(Map<String, dynamic> data) async {
    final token = data['accessToken']?.toString() ?? data['token']?.toString();
    final rawUser = data['user'];
    var userObject = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    final userId = userObject['id']?.toString() ?? data['userId']?.toString();

    if (token != null && token.isNotEmpty) {
      await _api.storage.write(key: 'jwt_token', value: token);

      if (userId != null && userId.isNotEmpty) {
        await _api.storage.write(key: 'user_id', value: userId);
      }

      if (userObject.isNotEmpty) {
        // Normalize moderationStatus / auth_status keys
        userObject['moderationStatus'] =
            userObject['moderationStatus'] ??
            userObject['moderation_status'] ??
            data['moderationStatus'] ??
            'INCOMPLETE';
        userObject['auth_status'] =
            userObject['auth_status'] ?? userObject['authStatus'] ?? 'ACTIVE';

        // Fetch live worker onboarding/moderation status right after saving token
        userObject = await _syncWorkerStatusIfPossible(userObject);

        await _api.storage.write(
          key: 'user_data',
          value: jsonEncode(userObject),
        );

        _ref.read(currentUserProvider.notifier).state = userObject;

        try {
          final mobile = userObject['mobile']?.toString();
          final notifService = _ref.read(notificationServiceProvider);

          await notifService.registerTokenAfterLogin();
          await notifService.subscribeToUserTopics(mobile);

          if (userId != null) {
            await _ref.read(socketServiceProvider).connect(userId);
          }
        } catch (e) {
          log('Setup Error on Login (Ignored): $e');
        }
      }

      _ref.read(isAuthenticatedProvider.notifier).state = true;
    }
  }

  // =======================================================
  // LOGOUT
  // =======================================================
  Future<void> logout(BuildContext context) async {
    try {
      final currentUser = _ref.read(currentUserProvider);

      if (currentUser != null) {
        try {
          await _api.dio.post('/fcm/remove-fcm', data: {});
          final mobile = currentUser['mobile']?.toString();
          await _ref
              .read(notificationServiceProvider)
              .unsubscribeFromTopics(mobile);
        } catch (e) {
          log('FCM Unsubscribe Error (Ignored): $e');
        }
      }
    } catch (_) {
    } finally {
      _ref.read(socketServiceProvider).disconnect();

      await _api.storage.delete(key: 'jwt_token');
      await _api.storage.delete(key: 'user_id');
      await _api.storage.delete(key: 'user_data');

      _ref.read(isAuthenticatedProvider.notifier).state = false;
      _ref.read(currentUserProvider.notifier).state = null;

      if (context.mounted) {
        context.go(AppRoutes.home);
      }
    }
  }
}
