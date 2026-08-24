import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerMenuRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // OWNER RESTAURANT
  // ============================================================

  Future<Map<String, dynamic>?> getOwnerRestaurant() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final response = await _supabase
        .from('restaurants')
        .select('id, name')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // MENU CATEGORIES
  // ============================================================

  Future<List<Map<String, dynamic>>> getCategories(
    String restaurantId,
  ) async {
    final response = await _supabase
        .from('menu_categories')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('sort_order')
        .order('name');

    return (response as List)
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Future<void> addCategory({
    required String restaurantId,
    required String name,
    required String description,
  }) async {
    final existing = await _supabase
        .from('menu_categories')
        .select('sort_order')
        .eq('restaurant_id', restaurantId)
        .order(
          'sort_order',
          ascending: false,
        )
        .limit(1);

    final nextSortOrder =
        existing.isEmpty
            ? 0
            : ((existing.first['sort_order']
                        as num?)
                    ?.toInt() ??
                0) +
                1;

    await _supabase
        .from('menu_categories')
        .insert({
          'restaurant_id': restaurantId,
          'name': name.trim(),
          'description': description.trim(),
          'sort_order': nextSortOrder,
          'is_active': true,
        });
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    required String description,
    required bool isActive,
  }) async {
    await _supabase
        .from('menu_categories')
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'is_active': isActive,
        })
        .eq('id', categoryId);
  }

  Future<void> deleteCategory(
    String categoryId,
  ) async {
    await _supabase
        .from('menu_categories')
        .delete()
        .eq('id', categoryId);
  }

  // ============================================================
  // MENU ITEMS
  // ============================================================

  Future<List<Map<String, dynamic>>> getMenuItems(
    String restaurantId,
  ) async {
    final response = await _supabase
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .order(
          'is_featured',
          ascending: false,
        )
        .order('name');

    return (response as List)
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Future<void> addMenuItem({
    required String restaurantId,
    String? categoryId,
    required String name,
    required String description,
    required double price,
    String? imageUrl,
    required bool isAvailable,
    required bool isFeatured,
  }) async {
    await _supabase
        .from('menu_items')
        .insert({
          'restaurant_id': restaurantId,
          'category_id': categoryId,
          'name': name.trim(),
          'description': description.trim(),
          'price': price,
          'image_url':
              imageUrl?.trim().isEmpty ?? true
                  ? null
                  : imageUrl!.trim(),
          'is_available': isAvailable,
          'is_featured': isFeatured,
        });
  }

  Future<void> updateMenuItem({
    required String menuItemId,
    String? categoryId,
    required String name,
    required String description,
    required double price,
    String? imageUrl,
    required bool isAvailable,
    required bool isFeatured,
  }) async {
    await _supabase
        .from('menu_items')
        .update({
          'category_id': categoryId,
          'name': name.trim(),
          'description': description.trim(),
          'price': price,
          'image_url':
              imageUrl?.trim().isEmpty ?? true
                  ? null
                  : imageUrl!.trim(),
          'is_available': isAvailable,
          'is_featured': isFeatured,
          'updated_at':
              DateTime.now().toIso8601String(),
        })
        .eq('id', menuItemId);
  }

  Future<void> toggleAvailability({
    required String menuItemId,
    required bool isAvailable,
  }) async {
    await _supabase
        .from('menu_items')
        .update({
          'is_available': isAvailable,
          'updated_at':
              DateTime.now().toIso8601String(),
        })
        .eq('id', menuItemId);
  }

  Future<void> toggleFeatured({
    required String menuItemId,
    required bool isFeatured,
  }) async {
    await _supabase
        .from('menu_items')
        .update({
          'is_featured': isFeatured,
          'updated_at':
              DateTime.now().toIso8601String(),
        })
        .eq('id', menuItemId);
  }

  Future<void> deleteMenuItem(
    String menuItemId,
  ) async {
    await _supabase
        .from('menu_items')
        .delete()
        .eq('id', menuItemId);
  }
}