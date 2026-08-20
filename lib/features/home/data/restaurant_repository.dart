
import 'package:supabase_flutter/supabase_flutter.dart';

import 'restaurant_model.dart';

class RestaurantRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<List<Restaurant>> getRestaurants({
    String search = '',
    String? halalStatus,
  }) async {
    var query = _supabase
        .from('restaurants')
        .select()
        .eq('is_active', true);

    final trimmedSearch = search.trim();

    if (trimmedSearch.isNotEmpty) {
      query = query.or(
        'name.ilike.%$trimmedSearch%,'
        'description.ilike.%$trimmedSearch%,'
        'city.ilike.%$trimmedSearch%,'
        'province.ilike.%$trimmedSearch%',
      );
    }

    if (halalStatus != null &&
        halalStatus.isNotEmpty) {
      query = query.eq(
        'halal_status',
        halalStatus,
      );
    }

    final response = await query
        .order(
          'is_featured',
          ascending: false,
        )
        .order(
          'average_rating',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => Restaurant.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<Restaurant> getRestaurantById(
    String restaurantId,
  ) async {
    final response = await _supabase
        .from('restaurants')
        .select()
        .eq('id', restaurantId)
        .single();

    return Restaurant.fromMap(
      Map<String, dynamic>.from(response),
    );
  }
}
