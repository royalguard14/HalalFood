import 'dart:async';

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
    _orderChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOrderItems() async {
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

  void _subscribeToOrderUpdates() {
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
            _handleOrderUpdate(payload);
          },
        )
        .subscribe();
  }

  void _handleOrderUpdate(
    PostgresChangePayload payload,
  ) {
    final updatedRecord = Map<String, dynamic>.from(
      payload.newRecord,
    );

    if (updatedRecord.isEmpty) {
      return;
    }

    try {
      final updatedOrder = Order.fromMap(
        updatedRecord,
      );

      if (!mounted) return;

      final oldStatus = _currentOrder.status;
      final newStatus = updatedOrder.status;

      setState(() {
        _currentOrder = updatedOrder;
      });

      if (oldStatus != newStatus) {
        _showStatusUpdateMessage(newStatus);
      }
    } catch (e) {
      debugPrint(
        'Unable to parse realtime order update: $e',
      );
    }
  }

  void _showStatusUpdateMessage(String status) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Order status updated to ${_displayStatus(status)}.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
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

  String _shortOrderId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(0, 8);
  }

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

            const SizedBox(height: 20),

            const Text(
              'Items',
              style: TextStyle(
                fontSize: 17,
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

  Widget _buildOrderHeader() {
    final statusColor =
        _statusColor(_currentOrder.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        HalalFoodTheme.primaryGreen
                            .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color:
                        HalalFoodTheme.primaryGreen,
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

                      const SizedBox(height: 3),

                      Text(
                        '#${_shortOrderId(_currentOrder.id)}',
                        style: const TextStyle(
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
                      const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color:
                        statusColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
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
                  Icons.calendar_today_outlined,
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
                    style: const TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildRealtimeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeIndicator() {
    final isFinished =
        _currentOrder.status == 'delivered' ||
        _currentOrder.status == 'cancelled' ||
        _currentOrder.status == 'refunded';

    if (isFinished) {
      return Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: _statusColor(
              _currentOrder.status,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _currentOrder.status == 'delivered'
                ? 'Order delivered'
                : 'Order ${_displayStatus(_currentOrder.status)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _statusColor(
                _currentOrder.status,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Live order status',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                HalalFoodTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildItems() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.redAccent,
              ),

              const SizedBox(height: 12),

              const Text(
                'Unable to load order items.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _loadOrderItems,
                child: const Text(
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
          padding: EdgeInsets.all(20),
          child: Text(
            'No items found for this order.',
            style: TextStyle(
              color:
                  HalalFoodTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ..._items.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final item = entry.value;

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
        item['item_name']?.toString() ??
            'Unknown item';

    final quantity =
        (item['quantity'] as num?)?.toInt() ??
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
          decoration: BoxDecoration(
            color:
                HalalFoodTheme.primaryGreen
                    .withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.restaurant_outlined,
            color:
                HalalFoodTheme.primaryGreen,
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
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '$quantity × ₱${unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(
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
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
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
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: isTotal
                  ? HalalFoodTheme.textPrimary
                  : HalalFoodTheme.textSecondary,
            ),
          ),
        ),

        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 13,
            fontWeight: FontWeight.w800,
            color: isTotal
                ? HalalFoodTheme.primaryGreen
                : HalalFoodTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    HalalFoodTheme.primaryGreen
                        .withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color:
                    HalalFoodTheme.primaryGreen,
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
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Payment status',
                    style: TextStyle(
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
                _currentOrder.paymentStatus,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}