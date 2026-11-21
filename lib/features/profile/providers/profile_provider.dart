import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/uploader_service.dart';
import '../../../shared/layouts/profile_drawer.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_model.dart';

typedef JsonMap = Map<String, dynamic>;

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

// ==========================================
// 1. FETCH WORKER PROFILE PROVIDER
// ==========================================
final workerProfileProvider = FutureProvider.autoDispose<WorkerProfileModel>((
  ref,
) async {
  try {
    final api = ref.watch(apiClientProvider);
    final response = await api.dio.get('/workers/profile');
    final raw = response.data;
    final JsonMap map = raw is Map ? JsonMap.from(raw) : JsonMap();
    return WorkerProfileModel.fromJson(map);
  } catch (e) {
    throw ApiException.fromDioException(e);
  }
});

final customerProfileProvider = workerProfileProvider;

// ==========================================
// 2. PROFILE MUTATION NOTIFIER (All API Writes)
// ==========================================
final profileMutationProvider =
    StateNotifierProvider.autoDispose<ProfileMutationNotifier, bool>((ref) {
      return ProfileMutationNotifier(ref);
    });

class ProfileMutationNotifier extends StateNotifier<bool> {
  final Ref _ref;

  ProfileMutationNotifier(this._ref) : super(false);

  /// Fetches the latest worker profile model directly for form pre-filling
  Future<WorkerProfileModel> fetchProfileForEdit() async {
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.dio.get('/workers/profile');
      final raw = response.data;
      final JsonMap map = raw is Map ? JsonMap.from(raw) : JsonMap();
      return WorkerProfileModel.fromJson(map);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Updates worker personal, legal, banking, professional, vehicle, and category details
  Future<ProfileUpdateResult> updateProfile(JsonMap payload) async {
    state = true;
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.dio.patch('/workers/profile', data: payload);

      _ref.invalidate(workerProfileProvider);

      // Sync updated fields into currentUserProvider so Drawer & Header react immediately
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
          if (payload['middleName'] != null)
            'middle_name': payload['middleName'],
          if (payload['lastName'] != null) 'last_name': payload['lastName'],
          if (payload['email'] != null) 'email': payload['email'],
          if (payload['mobile'] != null) 'mobile': payload['mobile'],
          if (payload['city'] != null) 'city': payload['city'],
          if (payload['address'] != null) 'address': payload['address'],
          if (payload['experience'] != null)
            'experience': payload['experience'],
          if (payload['description'] != null)
            'description': payload['description'],
          if (payload['legalType'] != null) 'legal_type': payload['legalType'],
          if (payload['inn'] != null) 'inn': payload['inn'],
          if (payload['companyName'] != null)
            'company_name': payload['companyName'],
          if (payload['image'] != null) 'image': payload['image'],
        };
      }

      final data = response.data is Map
          ? JsonMap.from(response.data as Map)
          : JsonMap();

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

  /// Uploads avatar to MinIO, persists it via PATCH /workers/profile, and returns the public URL
  Future<String> uploadAndSetAvatar(File file) async {
    state = true;
    _ref.read(isAvatarUploadingProvider.notifier).state = true;
    try {
      final uploader = _ref.read(uploaderServiceProvider);
      final publicUrl = await uploader.uploadFileDirectly(
        file: file,
        endpoint: '/workers/profile/upload-url',
        payloadData: {'folder': 'avatars'},
        compress: true,
        imageContext: 'avatar',
        isGetRequest: false,
      );

      final api = _ref.read(apiClientProvider);
      await api.dio.patch(
        '/workers/profile',
        data: {'image': publicUrl, 'avatarUrl': publicUrl},
      );

      _ref.invalidate(workerProfileProvider);

      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null) {
        _ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'image': publicUrl,
        };
      }

      return publicUrl;
    } catch (e) {
      throw ApiException.fromDioException(e);
    } finally {
      _ref.read(isAvatarUploadingProvider.notifier).state = false;
      if (mounted) state = false;
    }
  }
}
