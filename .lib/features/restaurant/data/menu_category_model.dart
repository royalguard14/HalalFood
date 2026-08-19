class MenuCategory {
  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isActive;

  const MenuCategory({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.sortOrder,
    required this.isActive,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? false,
    );
  }
}