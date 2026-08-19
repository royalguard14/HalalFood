import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryFoodResult {
  final String menuItemId;
  final String restaurantId;
  final String restaurantName;
  final String foodName;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isFeatured;

  const CategoryFoodResult({
    required this.menuItemId,
    required this.restaurantId,
    required this.restaurantName,
    required this.foodName,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isFeatured,
  });

  factory CategoryFoodResult.fromMap(
    Map<String, dynamic> map,
  ) {
    final restaurant =
        map['restaurants'] as Map<String, dynamic>?;

    return CategoryFoodResult(
      menuItemId: map['id'] as String,
      restaurantId:
          map['restaurant_id'] as String,
      restaurantName:
          restaurant?['name'] as String? ?? 'Restaurant',
      foodName:
          map['name'] as String? ?? '',
      description:
          map['description'] as String? ?? '',
      price:
          (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl:
          map['image_url'] as String?,
      isFeatured:
          map['is_featured'] as bool? ?? false,
    );
  }
}

class CategoryFoodRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<List<CategoryFoodResult>>
      getFoodsByCategory(
    String categoryId,
  ) async {
    final response = await _supabase
        .from('menu_items')
        .select(
          'id, restaurant_id, name, description, price, image_url, is_featured, restaurants(name)',
        )
        .eq('category_id', categoryId)
        .eq('is_available', true)
        .order(
          'is_featured',
          ascending: false,
        )
        .order(
          'name',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => CategoryFoodResult.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}