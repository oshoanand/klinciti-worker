import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_repository.dart';
import '../domain/category_model.dart';

/// A globally accessible provider that fetches and caches the category tree.
/// Using a FutureProvider automatically exposes .when(data:, loading:, error:) to the UI.
final publicCategoriesProvider = FutureProvider<List<CategoryModel>>((
  ref,
) async {
  final repository = ref.watch(categoryRepositoryProvider);

  // You can optionally add keepAlive logic here if you want the data
  // to persist in memory even when no screens are listening to it.
  ref.keepAlive();

  return repository.fetchPublicCategories();
});
