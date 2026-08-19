import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_item_model.dart';

class MenuItemRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<MenuItem>> getMenuItems(
    String restaurantId,
  ) async {
    final response = await _supabase
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .order('is_featured', ascending: false)
        .order('name');

    return (response as List)
        .map(
          (item) => MenuItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}