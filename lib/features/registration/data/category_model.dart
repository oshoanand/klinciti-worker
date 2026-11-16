class CategoryModel {
  final String id;
  final String name;
  final String? slug;
  final String? icon;
  final String? image;
  final String? parentId;
  final List<CategoryModel> subcategories;

  const CategoryModel({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    this.image,
    this.parentId,
    this.subcategories = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawSubs =
        (json['subcategories'] ?? json['children']) as List<dynamic>? ??
        const [];

    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      icon: json['icon']?.toString(),
      image: json['image']?.toString(),
      parentId: json['parent_id']?.toString() ?? json['parentId']?.toString(),
      subcategories: rawSubs
          .map(
            (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? icon,
    String? image,
    String? parentId,
    List<CategoryModel>? subcategories,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      image: image ?? this.image,
      parentId: parentId ?? this.parentId,
      subcategories: subcategories ?? this.subcategories,
    );
  }
}
