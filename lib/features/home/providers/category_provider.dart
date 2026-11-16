import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? image;

  CategoryModel({required this.id, required this.name, this.icon, this.image});

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      CategoryModel(id: json['id'], name: json['name'], icon: json['icon']);
}

final publicCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final response = await api.dio.get(
        '/categories/list',
      ); // Adjust endpoint if needed
      final List data = response.data is List
          ? response.data
          : response.data['data'] ?? [];
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    });
