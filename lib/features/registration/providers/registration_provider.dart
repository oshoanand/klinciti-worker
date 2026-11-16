import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/uploader_service.dart';
import '../data/category_model.dart';

typedef JsonMap = Map<String, dynamic>;

final registrationProvider = Provider<RegistrationController>((ref) {
  return RegistrationController(
    ref.watch(apiClientProvider),
    ref.watch(uploaderServiceProvider),
  );
});

final categoriesTreeProvider = FutureProvider.autoDispose<List<CategoryModel>>((
  ref,
) async {
  return ref.read(registrationProvider).fetchCategories();
});

class RegistrationController {
  final ApiClient _api;
  final UploaderService _uploader;

  RegistrationController(this._api, this._uploader);

  Future<JsonMap> checkStatus() async {
    try {
      final response = await _api.dio.get('/workers/onboarding/status');
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await _api.dio.get('/categories/list');
      final rawData = response.data;

      final List<dynamic> list = rawData is List
          ? rawData
          : (rawData is Map && rawData['categories'] is List
                ? rawData['categories'] as List
                : (rawData is Map && rawData['data'] is List
                      ? rawData['data'] as List
                      : const []));

      final parsed = list
          .map(
            (json) =>
                CategoryModel.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .toList();

      // If the backend already returned a nested tree (subcategories populated), return root nodes
      final hasPrebuiltChildren = parsed.any((c) => c.subcategories.isNotEmpty);
      if (hasPrebuiltChildren) {
        return parsed
            .where((c) => c.parentId == null || c.parentId!.isEmpty)
            .toList();
      }

      // Otherwise, group flat categories by `parentId` into a 2-level hierarchy
      final Map<String, List<CategoryModel>> childrenByParent = {};
      final List<CategoryModel> roots = [];

      for (final cat in parsed) {
        final pid = cat.parentId;
        if (pid == null || pid.isEmpty) {
          roots.add(cat);
        } else {
          childrenByParent.putIfAbsent(pid, () => []).add(cat);
        }
      }

      return roots.map((root) {
        final subs = childrenByParent[root.id] ?? const [];
        return root.copyWith(subcategories: subs);
      }).toList();
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> submitStep2(JsonMap data) async {
    try {
      await _api.dio.post('/workers/onboarding/step-2', data: data);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Uses UploaderService to compress and upload KYC documents to MinIO/S3
  Future<String> uploadDocument(File file, String type) async {
    try {
      return await _uploader.uploadFileDirectly(
        file: file,
        endpoint: '/workers/profile/upload-url',
        payloadData: {'folder': 'kyc/$type'},
        compress: true,
        imageContext: 'kyc',
        isGetRequest: false,
      );
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> submitStep3(JsonMap data) async {
    try {
      await _api.dio.post('/workers/onboarding/step-3', data: data);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> submitStep4(JsonMap data) async {
    try {
      await _api.dio.post('/workers/onboarding/step-4', data: data);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
