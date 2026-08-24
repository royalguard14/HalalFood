class MenuItem {
  final String id;
  final String restaurantId;
  final String? categoryId;
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
    this.categoryId,
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
      id: map['id'].toString(),
      restaurantId:
          map['restaurant_id'].toString(),
      categoryId:
          map['category_id']?.toString(),
      name:
          map['name']?.toString() ?? '',
      description:
          map['description']?.toString() ?? '',
      price:
          (map['price'] as num?)
                  ?.toDouble() ??
              0.0,
      imageUrl:
          map['image_url']?.toString(),
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
