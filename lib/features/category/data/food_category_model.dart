class FoodCategory {
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final bool isActive;
  final int sortOrder;

  const FoodCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    required this.isActive,
    required this.sortOrder,
  });

  factory FoodCategory.fromMap(
    Map<String, dynamic> map,
  ) {
    return FoodCategory(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      icon: map['icon'] as String?,
      isActive: map['is_active'] as bool? ?? false,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}