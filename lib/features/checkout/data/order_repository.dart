
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../address/data/address_model.dart';
import '../../cart/data/cart_item.dart';

class OrderRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<String> createOrder({
    required Address address,
    required String restaurantId,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    String? notes,
  }) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    if (items.isEmpty) {
      throw Exception(
        'Your cart is empty.',
      );
    }

    if (restaurantId.trim().isEmpty) {
      throw Exception(
        'Restaurant information is missing.',
      );
    }

    final totalAmount =
        subtotal + deliveryFee;

    final orderResponse = await _supabase
        .from('orders')
        .insert({
          'customer_id': user.id,
          'restaurant_id': restaurantId,
          'delivery_address_id': address.id,
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
          'total_amount': totalAmount,
          'notes': notes,
        })
        .select('id')
        .single();

    final orderId =
        orderResponse['id'] as String;

    try {
      final orderItems = items.map((cartItem) {
        return {
          'order_id': orderId,
          'menu_item_id': cartItem.item.id,
          'item_name': cartItem.item.name,
          'quantity': cartItem.quantity,
          'unit_price': cartItem.item.price,
          'subtotal': cartItem.subtotal,
        };
      }).toList();

      await _supabase
          .from('order_items')
          .insert(orderItems);

      return orderId;
    } catch (e) {
      // Remove the order if order items
      // could not be created.
      await _supabase
          .from('orders')
          .delete()
          .eq('id', orderId)
          .eq('customer_id', user.id);

      rethrow;
    }
  }
}
