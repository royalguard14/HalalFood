class MenuItem {
  final String id;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final bool isFeatured;
  final List<String> foodCategoryIds;

  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    required this.isFeatured,
    this.foodCategoryIds = const [],
  });

  factory MenuItem.fromMap(
    Map<String, dynamic> map,
  ) {
    final categoryLinks =
        map['menu_item_categories'];

    final foodCategoryIds =
        categoryLinks is List
            ? categoryLinks
                .whereType<Map>()
                .map(
                  (item) =>
                      item['food_category_id']
                          ?.toString(),
                )
                .whereType<String>()
                .toList()
            : <String>[];

    return MenuItem(
      id: map['id'] as String,
      restaurantId:
          map['restaurant_id'] as String,
      categoryId:
          map['category_id'] as String,
      name:
          map['name'] as String? ?? '',
      description:
          map['description'] as String? ?? '',
      price:
          (map['price'] as num?)
                  ?.toDouble() ??
              0.0,
      imageUrl:
          map['image_url'] as String?,
      isAvailable:
          map['is_available'] as bool? ??
              false,
      isFeatured:
          map['is_featured'] as bool? ??
              false,
      foodCategoryIds:
          foodCategoryIds,
    );
  }
}