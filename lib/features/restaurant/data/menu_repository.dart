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

  DateTime _monthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<Map<String, int>> _monthlySalesByItem(
    String restaurantId,
  ) async {
    final ordersResponse = await _supabase
        .from('orders')
        .select('id')
        .eq('restaurant_id', restaurantId)
        .eq('status', 'completed')
        .gte('created_at', _monthStart().toIso8601String());

    final orderIds = (ordersResponse as List)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();

    final sales = <String, int>{};
    if (orderIds.isEmpty) return sales;

    final itemsResponse = await _supabase
        .from('order_items')
        .select('menu_item_id, quantity')
        .inFilter('order_id', orderIds);

    for (final row in (itemsResponse as List)) {
      final menuItemId = row['menu_item_id']?.toString();
      if (menuItemId == null) continue;
      final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
      sales[menuItemId] = (sales[menuItemId] ?? 0) + quantity;
    }

    return sales;
  }

  Future<List<MenuItem>> getMenuItems(
    String restaurantId,
  ) async {
    final response = await _supabase
        .from('menu_items')
        .select('''
          id,
          restaurant_id,
          category_id,
          name,
          description,
          price,
          image_url,
          is_available,
          menu_item_categories (
            food_category_id
          )
        ''')
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .order('name', ascending: true);

    final salesByItem = await _monthlySalesByItem(restaurantId);
    final bestSellerCount = salesByItem.values.isEmpty
        ? 0
        : salesByItem.values.reduce((a, b) => a > b ? a : b);

    final items = (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
          final id = item['id']?.toString();
          final sold = id == null ? 0 : (salesByItem[id] ?? 0);
          item['is_featured'] = sold > 0 && sold == bestSellerCount;
          return MenuItem.fromMap(item);
        })
        .toList();

    items.sort((a, b) {
      if (a.isFeatured != b.isFeatured) {
        return a.isFeatured ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  Future<List<Map<String, dynamic>>> getFoodCategories() async {
    final response = await _supabase
        .from('food_categories')
        .select('id, name, slug, icon')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
