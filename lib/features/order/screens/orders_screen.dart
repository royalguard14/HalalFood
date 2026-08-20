import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/order_repository.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
  });

  @override
  State<OrdersScreen> createState() =>
      _OrdersScreenState();
}

class _OrdersScreenState
    extends State<OrdersScreen> {
  final _orderRepository = OrderRepository();

  List<Map<String, dynamic>> _orders = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orders =
          await _orderRepository.getOrders();

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load orders: $e',
          ),
        ),
      );
    }
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

    if (_orders.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: HalalFoodTheme.primaryGreen,
          ),
          SizedBox(height: 18),
          Center(
            child: Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 40,
              ),
              child: Text(
                'Your orders will appear here after you place an order.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      HalalFoodTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        32,
      ),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];

        return Padding(
          padding:
              const EdgeInsets.only(bottom: 14),
          child: _OrderCard(
            order: order,
            onTap: () {
              _openOrderDetails(order);
            },
          ),
        );
      },
    );
  }

  Future<void> _openOrderDetails(
    Map<String, dynamic> order,
  ) async {
    final orderId =
        order['id']?.toString();

    if (orderId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(
          order: order,
          orderRepository: _orderRepository,
        ),
      ),
    );

    if (mounted) {
      await _loadOrders();
    }
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        order['status']?.toString() ?? 'pending';

    final total =
        _toDouble(order['total_amount']);

    final createdAt =
        order['created_at']?.toString();

    final orderId =
        order['id']?.toString() ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: HalalFoodTheme
                          .primaryGreen
                          .withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
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
                          '#${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    status: status,
                  ),
                ],
              ),

              const Divider(height: 28),

              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      label: 'Total',
                      value:
                          '₱${total.toStringAsFixed(2)}',
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      label: 'Payment',
                      value:
                          _formatStatus(
                            order['payment_status']
                                ?.toString() ??
                                'pending',
                          ),
                    ),
                  ),
                ],
              ),

              if (createdAt != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color:
                            HalalFoodTheme
                                .textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final OrderRepository orderRepository;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.orderRepository,
  });

  @override
  State<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState
    extends State<OrderDetailsScreen> {
  List<Map<String, dynamic>> _items = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final orderId =
          widget.order['id']?.toString();

      if (orderId == null) {
        throw Exception(
          'Invalid order ID.',
        );
      }

      final items =
          await widget.orderRepository
              .getOrderItems(orderId);

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load order items: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        widget.order['status']
            ?.toString() ??
            'pending';

    final paymentStatus =
        widget.order['payment_status']
            ?.toString() ??
            'pending';

    final subtotal =
        _toDouble(
          widget.order['subtotal'],
        );

    final deliveryFee =
        _toDouble(
          widget.order['delivery_fee'],
        );

    final total =
        _toDouble(
          widget.order['total_amount'],
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32,
        ),
        children: [
          _StatusHeader(
            status: status,
            paymentStatus: paymentStatus,
          ),

          const SizedBox(height: 20),

          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          if (_isLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              ),
            )
          else if (_items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No order items found.',
                ),
              ),
            )
          else
            Card(
              clipBehavior:
                  Clip.antiAlias,
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ..._items.map(
                      (item) => _OrderItemRow(
                        item: item,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Subtotal',
                    value:
                        '₱${subtotal.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Delivery Fee',
                    value:
                        '₱${deliveryFee.toStringAsFixed(2)}',
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: Divider(),
                  ),
                  _SummaryRow(
                    label: 'Total',
                    value:
                        '₱${total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),

          if (widget.order['notes'] != null &&
              widget.order['notes']
                  .toString()
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Text(
                  widget.order['notes']
                      .toString(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrderItemRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        item['item_name']?.toString() ??
            'Item';

    final quantity =
        item['quantity'] ?? 0;

    final unitPrice =
        _toDouble(item['unit_price']);

    final subtotal =
        _toDouble(item['subtotal']);

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(10),
              color: HalalFoodTheme
                  .primaryGreen
                  .withValues(alpha: 0.08),
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
                  name,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
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

          const SizedBox(width: 10),

          Text(
            '₱${subtotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final String status;
  final String paymentStatus;

  const _StatusHeader({
    required this.status,
    required this.paymentStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusBadge(
                    status: status,
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: Colors.black12,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatStatus(
                      paymentStatus,
                    ),
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w800,
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
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized =
        status.toLowerCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'confirmed':
        background = Colors.blue
            .withValues(alpha: 0.10);
        foreground = Colors.blue;
        break;

      case 'preparing':
        background = Colors.orange
            .withValues(alpha: 0.12);
        foreground = Colors.orange.shade800;
        break;

      case 'ready':
        background = Colors.teal
            .withValues(alpha: 0.10);
        foreground = Colors.teal;
        break;

      case 'out_for_delivery':
        background = Colors.purple
            .withValues(alpha: 0.10);
        foreground = Colors.purple;
        break;

      case 'delivered':
        background = HalalFoodTheme
            .primaryGreen
            .withValues(alpha: 0.10);
        foreground =
            HalalFoodTheme.primaryGreen;
        break;

      case 'cancelled':
        background = Colors.red
            .withValues(alpha: 0.10);
        foreground = Colors.red;
        break;

      default:
        background = Colors.orange
            .withValues(alpha: 0.10);
        foreground = Colors.orange.shade800;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color:
                HalalFoodTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize:
                  isTotal ? 17 : 14,
              fontWeight:
                  isTotal
                      ? FontWeight.w800
                      : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize:
                isTotal ? 19 : 14,
            fontWeight:
                FontWeight.w800,
            color: isTotal
                ? HalalFoodTheme.primaryGreen
                : HalalFoodTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value.toString(),
      ) ??
      0;
}

String _formatStatus(String status) {
  return status
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _formatDate(String value) {
  final date =
      DateTime.tryParse(value);

  if (date == null) {
    return value;
  }

  final local = date.toLocal();

  final month = [
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
  ][local.month - 1];

  final hour =
      local.hour == 0
          ? 12
          : local.hour > 12
              ? local.hour - 12
              : local.hour;

  final minute =
      local.minute.toString().padLeft(2, '0');

  final period =
      local.hour >= 12 ? 'PM' : 'AM';

  return '$month ${local.day}, ${local.year} • '
      '$hour:$minute $period';
}