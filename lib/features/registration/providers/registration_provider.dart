import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/uploader_service.dart';
import '../data/category_model.dart';

typedef JsonMap = Map<String, dynamic>;

// ==========================================
// 1. ПРАВОВОЙ СТАТУС И СОСТОЯНИЕ ФОРМЫ
// ==========================================
enum LegalType { selfEmployed, ip, ooo }

extension LegalTypeExtension on LegalType {
  String toBackendString() {
    switch (this) {
      case LegalType.selfEmployed:
        return 'SELF_EMPLOYED';
      case LegalType.ip:
        return 'IP';
      case LegalType.ooo:
        return 'OOO';
    }
  }
}

class RegistrationState {
  // Данные Шага 2 (Юридический статус и профиль)
  final LegalType? legalType;
  final String? inn;
  final String? companyName;
  final String? city;
  final String? address;
  final String? experience;
  final String? description;
  final bool? hasVehicle;
  final List<String> selectedCategoryIds;

  // Данные Шага 4 (Банковские реквизиты РФ)
  final String? bankName;
  final String? bankBik;
  final String? checkingAccount;
  final String? correspondentAccount;

  const RegistrationState({
    this.legalType,
    this.inn,
    this.companyName,
    this.city,
    this.address,
    this.experience,
    this.description,
    this.hasVehicle,
    this.selectedCategoryIds = const [],
    this.bankName,
    this.bankBik,
    this.checkingAccount,
    this.correspondentAccount,
  });

  RegistrationState copyWith({
    LegalType? legalType,
    String? inn,
    String? companyName,
    String? city,
    String? address,
    String? experience,
    String? description,
    bool? hasVehicle,
    List<String>? selectedCategoryIds,
    String? bankName,
    String? bankBik,
    String? checkingAccount,
    String? correspondentAccount,
  }) {
    return RegistrationState(
      legalType: legalType ?? this.legalType,
      inn: inn ?? this.inn,
      companyName: companyName ?? this.companyName,
      city: city ?? this.city,
      address: address ?? this.address,
      experience: experience ?? this.experience,
      description: description ?? this.description,
      hasVehicle: hasVehicle ?? this.hasVehicle,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      bankName: bankName ?? this.bankName,
      bankBik: bankBik ?? this.bankBik,
      checkingAccount: checkingAccount ?? this.checkingAccount,
      correspondentAccount: correspondentAccount ?? this.correspondentAccount,
    );
  }
}

// ==========================================
// 2. ПРОВАЙДЕРЫ
// ==========================================

// Провайдер состояния формы (используется на экранах)
final registrationProvider =
    NotifierProvider<RegistrationNotifier, RegistrationState>(() {
      return RegistrationNotifier();
    });

// Провайдер API контроллера
final registrationApiProvider = Provider<RegistrationController>((ref) {
  return RegistrationController(
    ref.watch(apiClientProvider),
    ref.watch(uploaderServiceProvider),
  );
});

final categoriesTreeProvider = FutureProvider.autoDispose<List<CategoryModel>>((
  ref,
) async {
  return ref.read(registrationApiProvider).fetchCategories();
});

// ==========================================
// 3. NOTIFIER (Локальное сохранение данных между экранами)
// ==========================================
class RegistrationNotifier extends Notifier<RegistrationState> {
  @override
  RegistrationState build() {
    return const RegistrationState();
  }

  void updateStep2({
    required LegalType legalType,
    required String inn,
    String? companyName,
    required String city,
    required String address,
    required String experience,
    required String description,
    required bool hasVehicle,
  }) {
    state = state.copyWith(
      legalType: legalType,
      inn: inn,
      companyName: companyName,
      city: city,
      address: address,
      experience: experience,
      description: description,
      hasVehicle: hasVehicle,
    );
  }

  void updateStep4({
    required String bankName,
    required String bankBik,
    required String checkingAccount,
    required String correspondentAccount,
  }) {
    state = state.copyWith(
      bankName: bankName,
      bankBik: bankBik,
      checkingAccount: checkingAccount,
      correspondentAccount: correspondentAccount,
    );
  }

  void updateCategories(List<String> categoryIds) {
    state = state.copyWith(selectedCategoryIds: categoryIds);
  }

  // Методы отправки, которые собирают данные из state и передают в API
  Future<void> submitStep2ToServer() async {
    final payload = {
      'legalType': state.legalType?.toBackendString(),
      'inn': state.inn,
      'companyName': state.companyName,
      'city': state.city,
      'address': state.address,
      'experience': state.experience,
      'description': state.description,
      'hasVehicle': state.hasVehicle,
      'categoryIds': state.selectedCategoryIds,
    };
    await ref.read(registrationApiProvider).submitStep2(payload);
  }

  Future<void> submitStep4ToServer() async {
    final payload = {
      'bankName': state.bankName,
      'bankBik': state.bankBik,
      'checkingAccount': state.checkingAccount,
      'correspondentAccount': state.correspondentAccount,
    };
    await ref.read(registrationApiProvider).submitStep4(payload);
  }
}

// ==========================================
// 4. API КОНТРОЛЛЕР (Работа с сетью)
// ==========================================
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

      final hasPrebuiltChildren = parsed.any((c) => c.subcategories.isNotEmpty);
      if (hasPrebuiltChildren) {
        return parsed
            .where((c) => c.parentId == null || c.parentId!.isEmpty)
            .toList();
      }

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
