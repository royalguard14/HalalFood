import 'package:supabase_flutter/supabase_flutter.dart';

import '../../address/data/address_model.dart';
import '../../cart/data/cart_item.dart';

class OrderRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<double> getPickupDownpaymentPercent() async {
    final response = await _supabase.rpc('get_pickup_downpayment_percent');
    final value = (response as num?)?.toDouble();
    if (value == null || !value.isFinite || value < 0 || value > 100) {
      return 50.0;
    }
    return value;
  }

  Future<String> createOrder({
    Address? address,
    required String restaurantId,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    String? notes,
    String fulfillmentType = 'delivery',
    String? promoCode,
    double pickupDownpaymentPercent = 0,
    double pickupDownpaymentAmount = 0,
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

    if (fulfillmentType != 'delivery' && fulfillmentType != 'pickup') {
      throw Exception('Invalid fulfillment type.');
    }

    if (fulfillmentType == 'delivery' && address == null) {
      throw Exception('A delivery address is required for delivery orders.');
    }

    double effectiveDeliveryFee = deliveryFee;

    if (fulfillmentType == 'delivery') {
      final addressId = address!.id;

      final serverFee = await _supabase.rpc(
        'calculate_delivery_fee',
        params: {
          'p_restaurant_id': restaurantId,
          'p_address_id': addressId,
        },
      );

      final parsedFee = (serverFee as num?)?.toDouble();
      if (parsedFee == null ||
          !parsedFee.isFinite ||
          parsedFee < 0) {
        throw Exception('Unable to calculate a valid delivery fee.');
      }

      // The backend calculation is authoritative. This also enforces
      // maximum_delivery_distance_km before the order is created.
      effectiveDeliveryFee = parsedFee;
    } else {
      effectiveDeliveryFee = 0;
    }

    final effectivePickupPercent = fulfillmentType == 'pickup'
        ? pickupDownpaymentPercent.clamp(0, 100).toDouble()
        : 0.0;
    final effectivePickupAmount = fulfillmentType == 'pickup'
        ? pickupDownpaymentAmount.clamp(0, subtotal).toDouble()
        : 0.0;

    final totalAmount =
        subtotal + effectiveDeliveryFee;

    final orderResponse = await _supabase
        .from('orders')
        .insert({
          'customer_id': user.id,
          'restaurant_id': restaurantId,
          'delivery_address_id': address?.id,
          'fulfillment_type': fulfillmentType,
          'subtotal': subtotal,
          'delivery_fee': effectiveDeliveryFee,
          'total_amount': totalAmount,
          'pickup_downpayment_percent': effectivePickupPercent == 0 ? null : effectivePickupPercent,
          'pickup_downpayment_amount': effectivePickupAmount,
          'pickup_downpayment_status': fulfillmentType == 'pickup' ? 'pending' : 'not_required',
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

      if (promoCode != null && promoCode.trim().isNotEmpty) {
        await _supabase.rpc(
          'claim_promo_code',
          params: {
            'p_order_id': orderId,
            'p_code': promoCode.trim(),
          },
        );
      }

      if (fulfillmentType == 'pickup' && effectivePickupAmount > 0) {
        await _supabase.from('payments').insert({
          'order_id': orderId,
          'customer_id': user.id,
          'amount': effectivePickupAmount,
          'payment_method': 'online',
          'status': 'pending',
          'notes': 'Pickup downpayment required before restaurant processing. Non-refundable under pickup no-show rule.',
        });
      }

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
}
