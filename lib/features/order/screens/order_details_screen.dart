import 'package:flutter/material.dart';
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
  String? _error;

  RealtimeChannel? _orderChannel;

  @override
  void initState() {
    super.initState();

    _currentOrder = widget.order;

    _loadOrderItems();
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
    final value =
        status.trim().toLowerCase();

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
    final status =
        _normalizeStatus(
      _currentOrder.status,
    );

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

    final currentIndex =
        _statusIndex();

    final steps = [
      _TrackingStep(
        title: 'Order Placed',
        subtitle:
            'Your order has been received.',
        icon: Icons.receipt_long_rounded,
      ),
      _TrackingStep(
        title: 'Confirmed',
        subtitle:
            'The restaurant confirmed your order.',
        icon: Icons.check_circle_outline_rounded,
      ),
      _TrackingStep(
        title: 'Preparing',
        subtitle:
            'Your food is being prepared.',
        icon: Icons.restaurant_rounded,
      ),
      _TrackingStep(
        title: 'Ready for Pickup',
        subtitle:
            'Your order is ready for the rider.',
        icon: Icons.shopping_bag_outlined,
      ),
      _TrackingStep(
        title: 'Out for Delivery',
        subtitle:
            'Your rider is on the way.',
        icon: Icons.delivery_dining_rounded,
      ),
      _TrackingStep(
        title: 'Delivered',
        subtitle:
            'Enjoy your halal meal!',
        icon: Icons.home_rounded,
      ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          18,
          20,
          18,
          20,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons
                      .local_shipping_outlined,
                  color:
                      HalalFoodTheme
                          .primaryGreen,
                ),
                SizedBox(width: 10),
                Text(
                  'Order Tracking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ...steps.asMap().entries.map(
              (entry) {
                final index =
                    entry.key;
                final step =
                    entry.value;

                final isCompleted =
                    index < currentIndex;

                final isCurrent =
                    index == currentIndex;

                final isLast =
                    index ==
                        steps.length - 1;

                return _TrackingStepWidget(
                  step: step,
                  isCompleted:
                      isCompleted,
                  isCurrent:
                      isCurrent,
                  isLast: isLast,
                );
              },
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(
                  Icons.wifi_rounded,
                  size: 15,
                  color:
                      HalalFoodTheme
                          .primaryGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  'Status updates automatically',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        HalalFoodTheme
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

            _summaryRow(
              'Delivery Fee',
              '₱${_currentOrder.deliveryFee.toStringAsFixed(2)}',
            ),

            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 14,
              ),
              child: Divider(),
            ),

            _summaryRow(
              'Total',
              '₱${_currentOrder.totalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
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
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
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
                  12,
                ),
              ),
              child: const Icon(
                Icons
                    .payments_outlined,
                color:
                    HalalFoodTheme
                        .primaryGreen,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Payment status',
                    style:
                        TextStyle(
                      fontSize: 12,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Text(
              _displayStatus(
                _currentOrder
                    .paymentStatus,
              ),
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
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