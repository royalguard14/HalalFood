import 'package:supabase_flutter/supabase_flutter.dart';

import 'food_category_model.dart';

class FoodCategoryRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<List<FoodCategory>> getCategories() async {
    final response = await _supabase
        .from('food_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List)
        .map(
          (item) => FoodCategory.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}