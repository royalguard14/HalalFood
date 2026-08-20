
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../data/order_model.dart';
import '../data/order_repository.dart';

import 'order_details_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({
    super.key,
  });

  @override
  State<MyOrdersScreen> createState() =>
      _MyOrdersScreenState();
}

class _MyOrdersScreenState
    extends State<MyOrdersScreen> {
  final _orderRepository = OrderRepository();
  final _supabase = Supabase.instance.client;

  List<Order> _orders = [];

  bool _isLoading = true;

  String? _error;

  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();

    _loadOrders();
    _subscribeToOrderUpdates();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders =
          await _orderRepository.getMyOrders();

      if (!mounted) return;

      setState(() {
        _orders = orders;
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
    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'CUSTOMER REALTIME: no authenticated user',
      );
      return;
    }

    debugPrint(
      'CUSTOMER REALTIME: subscribing for customer ${user.id}',
    );

    _ordersChannel = _supabase
        .channel(
          'customer-orders-${user.id}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint(
              'CUSTOMER REALTIME EVENT: '
              '${payload.eventType}',
            );

            _handleRealtimeOrderChange(payload);
          },
        )
        .subscribe(
          (status, error) {
            debugPrint(
              'CUSTOMER REALTIME STATUS: $status',
            );

            if (error != null) {
              debugPrint(
                'CUSTOMER REALTIME ERROR: $error',
              );
            }
          },
        );
  }

  void _handleRealtimeOrderChange(
    PostgresChangePayload payload,
  ) {
    final newRecord =
        Map<String, dynamic>.from(
      payload.newRecord,
    );

    final oldRecord =
        Map<String, dynamic>.from(
      payload.oldRecord,
    );

    String? orderId;

    if (newRecord['id'] != null) {
      orderId = newRecord['id'].toString();
    } else if (oldRecord['id'] != null) {
      orderId = oldRecord['id'].toString();
    }

    if (orderId == null) {
      return;
    }

    if (payload.eventType ==
        PostgresChangeEvent.delete) {
      if (!mounted) return;

      setState(() {
        _orders.removeWhere(
          (order) => order.id == orderId,
        );
      });

      return;
    }

    if (newRecord.isEmpty) {
      return;
    }

    try {
      final updatedOrder =
          Order.fromMap(newRecord);

      if (!mounted) return;

      final existingIndex =
          _orders.indexWhere(
        (order) => order.id == updatedOrder.id,
      );

      setState(() {
        if (existingIndex >= 0) {
          _orders[existingIndex] = updatedOrder;
        } else {
          _orders.insert(
            0,
            updatedOrder,
          );
        }

        _orders.sort(
          (a, b) =>
              b.createdAt.compareTo(
            a.createdAt,
          ),
        );
      });

      debugPrint(
        'CUSTOMER REALTIME: '
        'order ${updatedOrder.id} '
        'status = ${updatedOrder.status}',
      );
    } catch (e) {
      debugPrint(
        'CUSTOMER REALTIME PARSE ERROR: $e',
      );
    }
  }

  String _formatDate(DateTime date) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${monthNames[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return Colors.green;

      case 'cancelled':
      case 'refunded':
        return Colors.red;

      case 'preparing':
      case 'ready':
      case 'on_the_way':
      case 'out_for_delivery':
        return Colors.orange;

      case 'confirmed':
        return Colors.blue;

      default:
        return HalalFoodTheme.primaryGreen;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 60,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign:
                        TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _loadOrders,
                    child: const Text(
                      'Try Again',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color:
                        HalalFoodTheme
                            .primaryGreen
                            .withValues(
                      alpha: 0.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No orders yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your completed and current orders will appear here.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        32,
      ),
      physics:
          const AlwaysScrollableScrollPhysics(),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];

        return Padding(
          padding: const EdgeInsets.only(
            bottom: 12,
          ),
          child: InkWell(
            borderRadius:
                BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      OrderDetailsScreen(
                    order: order,
                  ),
                ),
              );
            },
            child: _OrderCard(
              order: order,
              formatDate: _formatDate,
              statusColor:
                  _statusColor(order.status),
              displayStatus:
                  _displayStatus(order.status),
            ),
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final String Function(DateTime) formatDate;
  final Color statusColor;
  final String displayStatus;

  const _OrderCard({
    required this.order,
    required this.formatDate,
    required this.statusColor,
    required this.displayStatus,
  });

  String _shortOrderId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                    Icons.receipt_long_rounded,
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
                      const Text(
                        'Order',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              HalalFoodTheme
                                  .textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${_shortOrderId(order.id)}',
                        style:
                            const TextStyle(
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
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        statusColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    displayStatus,
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
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color:
                      HalalFoodTheme
                          .textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  formatDate(
                    order.createdAt,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        HalalFoodTheme
                            .textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        HalalFoodTheme
                            .primaryGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Text(
                  'Payment:',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        HalalFoodTheme
                            .textSecondary,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  order.paymentStatus
                      .replaceAll(
                        '_',
                        ' ',
                      ),
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
