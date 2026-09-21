
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cart/data/cart_item.dart';
import 'order_model.dart';

class OrderRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<String> createOrder({
    required String restaurantId,
    String? deliveryAddressId,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    String fulfillmentType = 'delivery',
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

    if (fulfillmentType != 'delivery' && fulfillmentType != 'pickup') {
      throw Exception('Invalid fulfillment type.');
    }

    if (fulfillmentType == 'delivery' && deliveryAddressId == null) {
      throw Exception('A delivery address is required for delivery orders.');
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
          'fulfillment_type': fulfillmentType,
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

  Future<void> cancelPickupOrder(String orderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');
    await _supabase.from('orders').update({'status': 'cancelled'})
      .eq('id', orderId).eq('customer_id', user.id)
      .eq('fulfillment_type', 'pickup')
      .inFilter('pickup_downpayment_status', ['pending', 'receipt_rejected']);
  }

  Future<void> submitPickupReceipt({required String orderId, required XFile receipt}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');
    final order = await _supabase.from('orders')
      .select('id,customer_id,fulfillment_type,pickup_downpayment_status')
      .eq('id', orderId).eq('customer_id', user.id).maybeSingle();
    if (order == null || order['fulfillment_type'] != 'pickup') throw Exception('Pickup order not found.');
    final state = order['pickup_downpayment_status']?.toString();
    if (state != 'pending' && state != 'receipt_rejected') throw Exception('This order is not waiting for a receipt.');
    final bytes = await receipt.readAsBytes();
    if (bytes.isEmpty) throw Exception('The selected receipt is empty.');
    final path = orderId + '/' + DateTime.now().microsecondsSinceEpoch.toString() + '.jpg';
    await _supabase.storage.from('payment-receipts').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    try {
      await _supabase.from('orders').update({
        'pickup_receipt_path': path,
        'pickup_receipt_submitted_at': DateTime.now().toUtc().toIso8601String(),
        'pickup_receipt_rejection_reason': null,
        'pickup_downpayment_status': 'receipt_submitted',
      }).eq('id', orderId).eq('customer_id', user.id);
    } catch (e) {
      await _supabase.storage.from('payment-receipts').remove([path]);
      rethrow;
    }
  }

  Future<void> rejectPickupReceipt({required String orderId, String? reason}) async {
    await _supabase.from('orders').update({
      'pickup_downpayment_status': 'receipt_rejected',
      'pickup_receipt_rejection_reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
    }).eq('id', orderId);
  }

  Future<void> confirmPickupReceipt(String orderId) async {
    await _supabase.from('orders').update({'pickup_downpayment_status': 'paid', 'payment_status': 'paid'}).eq('id', orderId);
  }

  Future<String?> getPickupReceiptSignedUrl(String path) async {
    if (path.trim().isEmpty) return null;
    return _supabase.storage.from('payment-receipts').createSignedUrl(path, 900);
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
