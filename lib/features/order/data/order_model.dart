
class Order {
  final String id;
  final String customerId;
  final String restaurantId;
  final String? deliveryAddressId;
  final String status;
  final String paymentStatus;
  final String fulfillmentType;
  final double pickupDownpaymentAmount;
  final String pickupDownpaymentStatus;
  final String? pickupReceiptPath;
  final DateTime? pickupReceiptSubmittedAt;
  final String? pickupReceiptRejectionReason;
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
    required this.fulfillmentType,
    required this.pickupDownpaymentAmount,
    required this.pickupDownpaymentStatus,
    required this.pickupReceiptPath,
    required this.pickupReceiptSubmittedAt,
    required this.pickupReceiptRejectionReason,
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
      fulfillmentType:
          map['fulfillment_type']?.toString() ?? 'delivery',
      pickupDownpaymentAmount:
          (map['pickup_downpayment_amount'] as num?)?.toDouble() ?? 0,
      pickupDownpaymentStatus:
          map['pickup_downpayment_status']?.toString() ?? 'not_required',
      pickupReceiptPath:
          map['pickup_receipt_path'] as String?,
      pickupReceiptSubmittedAt:
          map['pickup_receipt_submitted_at'] == null
              ? null
              : DateTime.tryParse(map['pickup_receipt_submitted_at'].toString()),
      pickupReceiptRejectionReason:
          map['pickup_receipt_rejection_reason'] as String?,
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
