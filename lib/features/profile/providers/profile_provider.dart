import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/uploader_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_model.dart';

class ProfileUpdateResult {
  final String message;
  final bool emailOtpSent;
  final bool phoneOtpSent;

  const ProfileUpdateResult({
    required this.message,
    this.emailOtpSent = false,
    this.phoneOtpSent = false,
  });
}

final workerProfileProvider = FutureProvider.autoDispose<WorkerProfileModel>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.dio.get('/workers/profile');
  return WorkerProfileModel.fromJson(
    Map<String, dynamic>.from(response.data as Map),
  );
});

final customerProfileProvider = workerProfileProvider;

final profileMutationProvider =
    StateNotifierProvider.autoDispose<ProfileMutationNotifier, bool>((ref) {
      return ProfileMutationNotifier(ref);
    });

class ProfileMutationNotifier extends StateNotifier<bool> {
  final Ref _ref;

  ProfileMutationNotifier(this._ref) : super(false);

  Future<ProfileUpdateResult> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    state = true;
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.dio.patch('/workers/profile', data: payload);

      _ref.invalidate(workerProfileProvider);

      // Sync updated name/contact fields into currentUserProvider
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null) {
        final updatedName = [
          payload['lastName'] ?? currentUser['last_name'],
          payload['firstName'] ?? currentUser['first_name'],
          payload['middleName'] ?? currentUser['middle_name'],
        ].where((s) => s != null && s.toString().trim().isNotEmpty).join(' ');

        _ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          if (updatedName.isNotEmpty) 'name': updatedName,
          if (payload['firstName'] != null) 'first_name': payload['firstName'],
          if (payload['lastName'] != null) 'last_name': payload['lastName'],
          if (payload['email'] != null) 'email': payload['email'],
          if (payload['mobile'] != null) 'mobile': payload['mobile'],
        };
      }

      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      return ProfileUpdateResult(
        message: data['message']?.toString() ?? 'Профиль успешно сохранен',
        emailOtpSent: data['emailOtpSent'] == true,
        phoneOtpSent: data['phoneOtpSent'] == true,
      );
    } catch (e) {
      throw ApiException.fromDioException(e);
    } finally {
      if (mounted) state = false;
    }
  }

  /// Verify newly added/updated email or phone with `profile_otp`
  Future<void> verifyContactOtp({
    required String type, // 'EMAIL' or 'MOBILE'
    required String target,
    required String otp,
  }) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.dio.post(
        '/workers/profile/verify-contact',
        data: {'type': type, 'target': target.trim(), 'otp': otp.trim()},
      );

      _ref.invalidate(workerProfileProvider);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Resend `profile_otp` with 50-second cooldown
  Future<void> resendContactOtp({
    required String type, // 'EMAIL' or 'MOBILE'
    required String target,
  }) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.dio.post(
        '/workers/profile/resend-contact-otp',
        data: {'type': type, 'target': target.trim()},
      );
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> uploadAndSetAvatar(File file) async {
    state = true;
    try {
      final uploader = _ref.read(uploaderServiceProvider);
      final publicUrl = await uploader.uploadFileDirectly(
        file: file,
        endpoint: '/workers/profile/upload-url',
        payloadData: {'folder': 'avatars'},
        compress: true,
        imageContext: 'avatars',
        isGetRequest: false,
      );

      final api = _ref.read(apiClientProvider);
      await api.dio.patch('/workers/profile', data: {'avatarUrl': publicUrl});

      _ref.invalidate(workerProfileProvider);

      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null) {
        _ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'image': publicUrl,
        };
      }
    } catch (e) {
      throw ApiException.fromDioException(e);
    } finally {
      if (mounted) state = false;
    }
  }
}
