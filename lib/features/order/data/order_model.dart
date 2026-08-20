
class Order {
  final String id;
  final String customerId;
  final String restaurantId;
  final String? deliveryAddressId;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.customerId,
    required this.restaurantId,
    required this.deliveryAddressId,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromMap(
    Map<String, dynamic> map,
  ) {
    return Order(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      restaurantId: map['restaurant_id'] as String,
      deliveryAddressId:
          map['delivery_address_id'] as String?,
      status: map['status'] as String,
      paymentStatus:
          map['payment_status'] as String,
      subtotal:
          (map['subtotal'] as num).toDouble(),
      deliveryFee:
          (map['delivery_fee'] as num).toDouble(),
      totalAmount:
          (map['total_amount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt:
          DateTime.parse(map['created_at'] as String),
      updatedAt:
          DateTime.parse(map['updated_at'] as String),
    );
  }
}
