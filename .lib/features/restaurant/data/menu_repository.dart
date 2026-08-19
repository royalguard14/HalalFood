import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_category_model.dart';
import 'menu_item_model.dart';

class MenuRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<MenuCategory>> getCategories(
    String restaurantId,
  ) async {
    final response = await _supabase
        .from('menu_categories')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List)
        .map(
          (item) => MenuCategory.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<MenuItem>> getMenuItems(
    String restaurantId,
  ) async {
    final response = await _supabase
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .order('is_featured', ascending: false)
        .order('name', ascending: true);

    return (response as List)
        .map(
          (item) => MenuItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}