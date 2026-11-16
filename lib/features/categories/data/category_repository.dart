import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../domain/category_model.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(apiClientProvider));
});

class CategoryRepository {
  final ApiClient _api;

  CategoryRepository(this._api);

  /// Fetches all active categories.
  /// The backend now returns a nested hierarchy (parents with their subcategories).
  Future<List<CategoryModel>> fetchPublicCategories() async {
    try {
      // Assuming your Fastify route is mounted at /categories in your main app.ts/server.ts
      final res = await _api.dio.get('/categories/list');

      final List data = res.data;
      return data
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException.fromDioException(e as dynamic);
    }
  }
}
