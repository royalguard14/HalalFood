import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../data/order_model.dart';
import '../data/order_repository.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState
    extends State<OrderDetailsScreen> {
  final _orderRepository = OrderRepository();
  final _supabase = Supabase.instance.client;

  late Order _currentOrder;

  List<Map<String, dynamic>> _items = [];

  bool _isLoading = true;
  bool _isUploadingReceipt = false;
  String? _error;
  Map<String, dynamic>? _restaurantPayment;
  double _cashPaidAmount = 0;

  RealtimeChannel? _orderChannel;

  @override
  void initState() {
    super.initState();

    _currentOrder = widget.order;

    _loadOrderItems();
    _loadRestaurantPayment();
    _loadCashPaidAmount();
    _subscribeToOrderUpdates();
  }

  @override
  void dispose() {
    if (_orderChannel != null) {
      _supabase.removeChannel(_orderChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // LOAD ORDER ITEMS
  // ============================================================

  Future<void> _loadOrderItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items =
          await _orderRepository.getOrderItems(
        _currentOrder.id,
      );

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadRestaurantPayment() async {
    try {
      final response = await _supabase.from('restaurants').select('gcash_name,gcash_number,gcash_qr_url').eq('id', _currentOrder.restaurantId).maybeSingle();
      if (mounted) setState(() => _restaurantPayment = response);
    } catch (e) { debugPrint('PICKUP PAYMENT DETAILS ERROR: $e'); }
  }

  Future<void> _loadCashPaidAmount() async {
    try {
      final response = await _supabase
          .from('payments')
          .select('amount')
          .eq('order_id', _currentOrder.id)
          .eq('payment_method', 'cash_on_delivery')
          .eq('status', 'paid');

      final total = (response as List).fold<double>(
        0,
        (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
      );

      if (mounted) {
        setState(() => _cashPaidAmount = total);
      }
    } catch (e) {
      debugPrint('CASH PAYMENT LOAD ERROR: ' + e.toString());
    }
  }
  Future<void> _uploadDownpaymentReceipt() async {
    if (_isUploadingReceipt) return;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null || !mounted) return;
      setState(() => _isUploadingReceipt = true);
      await _orderRepository.submitCustomerDownpaymentReceipt(
        orderId: _currentOrder.id,
        receipt: image,
      );
      final updated = await _supabase.from('orders').select().eq('id', _currentOrder.id).single();
      if (!mounted) return;
      setState(() {
        _currentOrder = Order.fromMap(Map<String, dynamic>.from(updated));
        _isUploadingReceipt = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt submitted. The restaurant can now review your downpayment.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingReceipt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to upload receipt: $e')),
      );
    }
  }
  // ============================================================
  // REALTIME ORDER STATUS
  // ============================================================

  void _subscribeToOrderUpdates() {
    debugPrint(
      'ORDER DETAILS REALTIME: '
      'subscribing to ${_currentOrder.id}',
    );

    _orderChannel = _supabase
        .channel(
          'order-details-${_currentOrder.id}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _currentOrder.id,
          ),
          callback: (payload) {
            debugPrint(
              'ORDER DETAILS REALTIME EVENT: '
              '${payload.eventType}',
            );

            _handleOrderUpdate(payload);
          },
        )
        .subscribe(
          (status, error) {
            debugPrint(
              'ORDER DETAILS REALTIME STATUS: $status',
            );

            if (error != null) {
              debugPrint(
                'ORDER DETAILS REALTIME ERROR: $error',
              );
            }
          },
        );
  }

  void _handleOrderUpdate(
    PostgresChangePayload payload,
  ) {
    final updatedRecord =
        Map<String, dynamic>.from(
      payload.newRecord,
    );

    if (updatedRecord.isEmpty) {
      return;
    }

    try {
      final updatedOrder =
          Order.fromMap(updatedRecord);

      if (!mounted) return;

      final oldStatus =
          _currentOrder.status;

      final newStatus =
          updatedOrder.status;

      setState(() {
        _currentOrder = updatedOrder;
      });

      _loadCashPaidAmount();

      debugPrint(
        'ORDER STATUS: '
        '$oldStatus → $newStatus',
      );

      if (oldStatus != newStatus) {
        _showStatusUpdateMessage(
          newStatus,
        );
      }
    } catch (e) {
      debugPrint(
        'ORDER REALTIME PARSE ERROR: $e',
      );
    }
  }

  void _showStatusUpdateMessage(
    String status,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Order status updated to '
                  '${_displayStatus(status)}.',
                ),
              ),
            ],
          ),
          duration:
              const Duration(seconds: 3),
        ),
      );
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  String _normalizeStatus(String status) {
    final value = status.trim().toLowerCase();

    switch (value) {
      case 'pending':
      case 'placed':
      case 'order_placed':
        return 'placed';

      case 'confirmed':
      case 'accepted':
        return 'confirmed';

      case 'preparing':
      case 'in_preparation':
        return 'preparing';

      case 'ready':
      case 'ready_for_pickup':
        return 'ready';

      case 'full_payment':
      case 'payment_due':
        return 'full_payment';

      case 'claimed':
      case 'picked_up':
      case 'pickedup':
        return 'claimed';

      case 'on_the_way':
      case 'out_for_delivery':
      case 'out_for_pickup':
        return 'out_for_delivery';

      case 'delivered':
      case 'completed':
        return 'delivered';

      case 'cancelled':
      case 'canceled':
        return 'cancelled';

      case 'refunded':
        return 'refunded';

      default:
        return value;
    }
  }

  String _displayStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                  '${word.substring(1)}',
        )
        .join(' ');
  }

  int _statusIndex() {
    final rawStatus = _currentOrder.status.trim().toLowerCase();
    final isPickup = _currentOrder.fulfillmentType == 'pickup';
    final status = _normalizeStatus(_currentOrder.status);

    if (isPickup) {
      // Pickup uses "claimed" as its terminal tracking step.
      // Final records may be stored as "completed" or "delivered".
      if (rawStatus == 'completed' || rawStatus == 'delivered') {
        return 5;
      }

      // Final Pickup payment is stored on payment_status while the
      // order status remains "ready" until the customer claims it.
      if (_currentOrder.paymentStatus.toLowerCase() == 'paid') {
        return 4;
      }

      switch (status) {
        case 'placed':
          return 0;
        case 'confirmed':
          return 1;
        case 'preparing':
          return 2;
        case 'ready':
          return 3;
        case 'full_payment':
          return 4;
        case 'claimed':
          return 5;
        default:
          return 0;
      }
    }

    switch (status) {
      case 'placed':
        return 0;
      case 'confirmed':
        return 1;
      case 'preparing':
        return 2;
      case 'ready':
        return 3;
      case 'out_for_delivery':
        return 4;
      case 'delivered':
        return 5;
      default:
        return 0;
    }
  }

  bool _isCancelled() {
    final status =
        _normalizeStatus(
      _currentOrder.status,
    );

    return status == 'cancelled' ||
        status == 'refunded';
  }

  Color _statusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'delivered':
        return Colors.green;

      case 'cancelled':
      case 'refunded':
        return Colors.red;

      case 'preparing':
      case 'ready':
      case 'out_for_delivery':
        return Colors.orange;

      case 'confirmed':
        return Colors.blue;

      default:
        return HalalFoodTheme.primaryGreen;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${monthNames[date.month - 1]} '
        '${date.day}, '
        '${date.year} at '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _shortOrderId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(0, 8);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrderItems,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32,
          ),
          children: [
            _buildOrderHeader(),

            const SizedBox(height: 18),

            _buildOrderTracking(),

            const SizedBox(height: 22),

            const Text(
              'Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 10),

            _buildItems(),

            const SizedBox(height: 20),

            _buildSummary(),

            const SizedBox(height: 20),

            _buildPaymentStatus(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDER HEADER
  // ============================================================

  Widget _buildOrderHeader() {
    final statusColor =
        _statusColor(
      _currentOrder.status,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    color:
                        HalalFoodTheme
                            .primaryGreen
                            .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .receipt_long_rounded,
                    color:
                        HalalFoodTheme
                            .primaryGreen,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              HalalFoodTheme
                                  .textSecondary,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '#${_shortOrderId(_currentOrder.id)}',
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color: statusColor
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    _displayStatus(
                      _currentOrder.status,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons
                      .calendar_today_outlined,
                  size: 17,
                  color:
                      HalalFoodTheme
                          .textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(
                      _currentOrder.createdAt,
                    ),
                    style:
                        const TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        _isCancelled()
                            ? Colors.red
                            : Colors.green,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _isCancelled()
                      ? 'Order ${_displayStatus(_currentOrder.status)}'
                      : _currentOrder.status
                                  .toLowerCase() ==
                              'delivered'
                          ? 'Order delivered'
                          : 'Live order tracking',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        _isCancelled()
                            ? Colors.red
                            : HalalFoodTheme
                                .textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDER TRACKING
  // ============================================================

  Widget _buildOrderTracking() {
    if (_isCancelled()) {
      return _buildCancelledTracking();
    }

    final currentIndex = _statusIndex();
    final isPickup = _currentOrder.fulfillmentType == 'pickup';

    final steps = isPickup
        ? [
            _TrackingStep(
              title: 'Order Placed',
              subtitle: 'Your pickup order has been received.',
              icon: Icons.receipt_long_rounded,
            ),
            _TrackingStep(
              title: 'Confirmed',
              subtitle: 'The restaurant confirmed your order.',
              icon: Icons.check_circle_outline_rounded,
            ),
            _TrackingStep(
              title: 'Preparing',
              subtitle: 'Your food is being prepared.',
              icon: Icons.restaurant_rounded,
            ),
            _TrackingStep(
              title: 'Ready to Pick Up',
              subtitle: 'Your order is ready at the restaurant.',
              icon: Icons.shopping_bag_outlined,
            ),
            _TrackingStep(
              title: 'Full Payment',
              subtitle: 'Pay the remaining balance before claiming your order.',
              icon: Icons.payments_outlined,
            ),
            _TrackingStep(
              title: 'Claimed',
              subtitle: 'Your order has been paid and claimed. Enjoy your halal meal!',
              icon: Icons.check_circle_rounded,
            ),
          ]
        : [
            _TrackingStep(
              title: 'Order Placed',
              subtitle: 'Your order has been received.',
              icon: Icons.receipt_long_rounded,
            ),
            _TrackingStep(
              title: 'Confirmed',
              subtitle: 'The restaurant confirmed your order.',
              icon: Icons.check_circle_outline_rounded,
            ),
            _TrackingStep(
              title: 'Preparing',
              subtitle: 'Your food is being prepared.',
              icon: Icons.restaurant_rounded,
            ),
            _TrackingStep(
              title: 'Ready for Pickup',
              subtitle: 'Your order is ready for the rider.',
              icon: Icons.shopping_bag_outlined,
            ),
            _TrackingStep(
              title: 'Out for Delivery',
              subtitle: 'Your rider is on the way.',
              icon: Icons.delivery_dining_rounded,
            ),
            _TrackingStep(
              title: 'Delivered',
              subtitle: 'Enjoy your halal meal!',
              icon: Icons.home_rounded,
            ),
          ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPickup
                      ? Icons.shopping_bag_outlined
                      : Icons.local_shipping_outlined,
                  color: HalalFoodTheme.primaryGreen,
                ),
                const SizedBox(width: 10),
                Text(
                  isPickup ? 'Pickup Tracking' : 'Order Tracking',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isCompleted = index < currentIndex;
              final isCurrent = index == currentIndex;
              final isLast = index == steps.length - 1;

              return _TrackingStepWidget(
                step: step,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isLast: isLast,
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: HalalFoodTheme.primaryGreen,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isPickup
                        ? 'Live pickup order tracking'
                        : 'Live order tracking',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledTracking() {
    final isRefunded =
        _normalizeStatus(
              _currentOrder.status,
            ) ==
            'refunded';

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    Colors.red
                        .withValues(
                  alpha: 0.10,
                ),
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                isRefunded
                    ? Icons
                        .currency_exchange_rounded
                    : Icons
                        .cancel_outlined,
                color: Colors.red,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRefunded
                        ? 'This order has been refunded.'
                        : 'This order has been cancelled.',
                    style:
                        const TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ITEMS
  // ============================================================

  Widget _buildItems() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(30),
          child: Center(
            child:
                CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                size: 48,
                color:
                    Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load order items.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    _loadOrderItems,
                child:
                    const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(20),
          child: Text(
            'No items found for this order.',
            style: TextStyle(
              color:
                  HalalFoodTheme
                      .textSecondary,
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            ..._items.asMap().entries.map(
              (entry) {
                final index =
                    entry.key;
                final item =
                    entry.value;

                return Column(
                  children: [
                    _buildItemRow(item),
                    if (index <
                        _items.length - 1)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        child: Divider(
                          height: 1,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(
    Map<String, dynamic> item,
  ) {
    final itemName =
        item['item_name']
                ?.toString() ??
            'Unknown item';

    final quantity =
        (item['quantity'] as num?)
                ?.toInt() ??
            0;

    final unitPrice =
        (item['unit_price'] as num?)
                ?.toDouble() ??
            0;

    final subtotal =
        (item['subtotal'] as num?)
                ?.toDouble() ??
            0;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration:
              BoxDecoration(
            color:
                HalalFoodTheme
                    .primaryGreen
                    .withValues(
              alpha: 0.08,
            ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: const Icon(
            Icons
                .restaurant_outlined,
            color:
                HalalFoodTheme
                    .primaryGreen,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                itemName,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '$quantity × ₱${unitPrice.toStringAsFixed(2)}',
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      HalalFoodTheme
                          .textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Text(
          '₱${subtotal.toStringAsFixed(2)}',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ORDER SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 16),

            _summaryRow(
              'Subtotal',
              '₱${_currentOrder.subtotal.toStringAsFixed(2)}',
            ),

            const SizedBox(height: 10),

            if (_currentOrder.fulfillmentType == 'pickup') ...[
              if (_currentOrder.promoDiscount > 0.005) ...[
                _summaryRow(
                  'Promo',
                  '-₱' + _currentOrder.promoDiscount.toStringAsFixed(2),
                ),
                const SizedBox(height: 10),
              ],

              _summaryRow(
                'Downpayment',
                '-₱${(_currentOrder.pickupDownpaymentStatus.toLowerCase() == 'paid' ? _currentOrder.pickupDownpaymentAmount : 0).toStringAsFixed(2)}',
              ),

              if (_cashPaidAmount > 0.005) ...[
                const SizedBox(height: 10),
                _summaryRow(
                  'Cash',
                  '₱${_cashPaidAmount.toStringAsFixed(2)}',
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(),
              ),

              _summaryRow(
                'Balance',
                '₱${(_currentOrder.paymentStatus.toLowerCase() == 'paid'
                        ? 0
                        : (_currentOrder.totalAmount -
                                (_currentOrder.pickupDownpaymentStatus.toLowerCase() == 'paid'
                                    ? _currentOrder.pickupDownpaymentAmount
                                    : 0) -
                                _cashPaidAmount)
                            .clamp(0, double.infinity))
                    .toStringAsFixed(2)}',
                isTotal: true,
              ),
            ] else ...[
              if (_currentOrder.promoDiscount > 0.005) ...[
                _summaryRow(
                  'Promo',
                  '-₱' + _currentOrder.promoDiscount.toStringAsFixed(2),
                ),
                const SizedBox(height: 10),
              ],
              _summaryRow(
                'Delivery Fee',
                '₱' + _currentOrder.deliveryFee.toStringAsFixed(2),
              ),
              const SizedBox(height: 10),
              _summaryRow(
                'Downpayment',
                '-₱' + (_currentOrder.pickupDownpaymentStatus.toLowerCase() == 'paid'
                    ? _currentOrder.pickupDownpaymentAmount
                    : 0).toStringAsFixed(2),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(),
              ),
              _summaryRow(
                'Balance',
                '₱' + (_currentOrder.paymentStatus.toLowerCase() == 'paid'
                    ? 0
                    : (_currentOrder.totalAmount -
                        (_currentOrder.pickupDownpaymentStatus.toLowerCase() == 'paid'
                            ? _currentOrder.pickupDownpaymentAmount
                            : 0)).clamp(0, double.infinity)).toStringAsFixed(2),
                isTotal: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize:
                  isTotal ? 15 : 13,
              fontWeight: isTotal
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: isTotal
                  ? HalalFoodTheme
                      .textPrimary
                  : HalalFoodTheme
                      .textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize:
                isTotal ? 18 : 13,
            fontWeight:
                FontWeight.w800,
            color: isTotal
                ? HalalFoodTheme
                    .primaryGreen
                : HalalFoodTheme
                    .textPrimary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT
  // ============================================================

  Widget _buildPaymentStatus() {
    final isPickup = _currentOrder.fulfillmentType == 'pickup';
    final state = _currentOrder.pickupDownpaymentStatus;
    final needsReceipt = state == 'pending' || state == 'receipt_rejected';
    final submitted = state == 'receipt_submitted';
    final paid = state == 'paid';

    if (paid) return const SizedBox.shrink();

    final amount = _currentOrder.pickupDownpaymentAmount;
    final gcashName = _restaurantPayment?['gcash_name']?.toString().trim() ?? '';
    final gcashNumber = _restaurantPayment?['gcash_number']?.toString().trim() ?? '';
    final qrUrl = _restaurantPayment?['gcash_qr_url']?.toString().trim() ?? '';

    final title = isPickup ? 'Pickup Downpayment' : 'Delivery Downpayment';
    final instruction = isPickup
        ? 'Pay directly to the restaurant GCash account, then upload your successful payment receipt.'
        : 'Pay the required delivery downpayment to the restaurant GCash account, then upload your successful payment receipt. The remaining balance already includes the delivery fee.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('₱' + amount.toStringAsFixed(2), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: HalalFoodTheme.primaryGreen)),
            const SizedBox(height: 12),
            if (needsReceipt) ...[
              Text(instruction, style: const TextStyle(height: 1.4)),
              if (gcashName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('GCash Name: ' + gcashName, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
              if (gcashNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('GCash Number: ' + gcashNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
              if (qrUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(qrUrl, height: 190, width: 190, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Unable to load GCash QR.')),
                ),
              ],
              if (state == 'receipt_rejected') ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Text('Receipt rejected' + (_currentOrder.pickupReceiptRejectionReason == null ? '.' : ': ' + _currentOrder.pickupReceiptRejectionReason!), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUploadingReceipt ? null : _uploadDownpaymentReceipt,
                  icon: _isUploadingReceipt ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file_rounded),
                  label: Text(_isUploadingReceipt ? 'Uploading...' : 'Upload Receipt'),
                ),
              ),
            ] else if (submitted) ...[
              const SizedBox(height: 8),
              const Text('Receipt submitted. Waiting for the restaurant to verify the downpayment.', style: TextStyle(height: 1.4, fontWeight: FontWeight.w600)),
            ] else ...[
              Text('Payment status: ' + _displayStatus(state)),
            ],
          ],
        ),
      ),
    );
  }

// ============================================================
// TRACKING STEP MODEL
// ============================================================

class _TrackingStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TrackingStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

// ============================================================
// TRACKING STEP WIDGET
// ============================================================

class _TrackingStepWidget
    extends StatelessWidget {
  final _TrackingStep step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _TrackingStepWidget({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final activeColor =
        HalalFoodTheme.primaryGreen;

    final inactiveColor =
        Colors.grey.shade300;

    final textColor =
        isCompleted || isCurrent
            ? HalalFoodTheme.textPrimary
            : HalalFoodTheme
                .textSecondary;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Column(
            children: [
              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 300,
                ),
                width: isCurrent
                    ? 42
                    : 38,
                height: isCurrent
                    ? 42
                    : 38,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color: isCompleted ||
                          isCurrent
                      ? activeColor
                      : inactiveColor,
                  boxShadow:
                      isCurrent
                          ? [
                              BoxShadow(
                                color:
                                    activeColor.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : step.icon,
                  size: 20,
                  color:
                      isCompleted ||
                              isCurrent
                          ? Colors.white
                          : Colors.grey
                              .shade500,
                ),
              ),

              if (!isLast)
                Container(
                  width: 2,
                  height: 46,
                  margin:
                      const EdgeInsets
                          .symmetric(
                    vertical: 3,
                  ),
                  color: isCompleted
                      ? activeColor
                      : inactiveColor,
                ),
            ],
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(
              top: 2,
              bottom: 18,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: TextStyle(
                          fontSize:
                              isCurrent
                                  ? 15
                                  : 14,
                          fontWeight:
                              isCurrent ||
                                      isCompleted
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                          color:
                              textColor,
                        ),
                      ),
                    ),

                    if (isCurrent)
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              activeColor.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),
                        child:
                            const Text(
                          'CURRENT',
                          style:
                              TextStyle(
                            fontSize: 9,
                            fontWeight:
                                FontWeight
                                    .w900,
                            color:
                                HalalFoodTheme
                                    .primaryGreen,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  step.subtitle,
                  style:
                      TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color:
                        isCurrent ||
                                isCompleted
                            ? HalalFoodTheme
                                .textSecondary
                            : Colors.grey
                                .shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}