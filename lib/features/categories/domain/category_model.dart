class CategoryModel {
  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? icon;
  final List<CategoryModel> subcategories;

  CategoryModel({
    required this.id,
    this.parentId,
    required this.name,
    required this.slug,
    this.icon,
    this.subcategories = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'].toString(),
      parentId: json['parent_id']?.toString(),
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      icon: json['icon'],
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
                .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }
}
