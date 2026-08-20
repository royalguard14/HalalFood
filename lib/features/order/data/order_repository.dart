
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cart/data/cart_item.dart';
import 'order_model.dart';

class OrderRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<String> createOrder({
    required String restaurantId,
    required String deliveryAddressId,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;

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

    final totalAmount =
        subtotal + deliveryFee;

    final orderResponse = await _supabase
        .from('orders')
        .insert({
          'customer_id': user.id,
          'restaurant_id': restaurantId,
          'delivery_address_id':
              deliveryAddressId,
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
      await _supabase
          .from('orders')
          .delete()
          .eq('id', orderId)
          .eq('customer_id', user.id);

      rethrow;
    }
  }

  Future<List<Order>> getMyOrders() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    final response = await _supabase
        .from('orders')
        .select()
        .eq('customer_id', user.id)
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => Order.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    final response = await _supabase
        .from('orders')
        .select()
        .eq('customer_id', user.id)
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getOrderItems(
    String orderId,
  ) async {
    final response = await _supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId);

    return (response as List)
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }
}
