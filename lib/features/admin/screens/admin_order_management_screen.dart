import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class AdminOrderManagementScreen extends StatefulWidget {
  const AdminOrderManagementScreen({super.key});

  @override
  State<AdminOrderManagementScreen> createState() =>
      _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState
    extends State<AdminOrderManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _filter = 'all';
  String _search = '';
  List<Map<String, dynamic>> _orders = [];

  static const _statusFilters = [
    ('All', 'all'),
    ('Pending', 'pending'),
    ('Confirmed', 'confirmed'),
    ('Preparing', 'preparing'),
    ('Ready', 'ready'),
    ('Out for Delivery', 'out_for_delivery'),
    ('Delivered', 'delivered'),
    ('Cancelled', 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _supabase
          .from('orders')
          .select(
            'id, customer_id, restaurant_id, delivery_address_id, status, '
            'payment_status, subtotal, delivery_fee, total_amount, notes, '
            'created_at, updated_at',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _orders = (response as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _normalizeStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pending':
      case 'placed':
      case 'order_placed':
        return 'pending';
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
      case 'completed':
      case 'delivered':
        return 'delivered';
      case 'canceled':
      case 'cancelled':
        return 'cancelled';
      default:
        return value.trim().toLowerCase();
    }
  }

  String _displayStatus(String value) {
    final normalized = _normalizeStatus(value);
    return normalized
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Color _statusColor(String value) {
    switch (_normalizeStatus(value)) {
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
      case 'ready':
      case 'out_for_delivery':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return HalalFoodTheme.primaryGreen;
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _search.toLowerCase();
    return _orders.where((order) {
      final status = _normalizeStatus(order['status']?.toString() ?? 'pending');
      final id = order['id']?.toString().toLowerCase() ?? '';
      final customer = order['customer_id']?.toString().toLowerCase() ?? '';
      final restaurant = order['restaurant_id']?.toString().toLowerCase() ?? '';

      final matchesFilter = _filter == 'all' || status == _filter;
      final matchesSearch = query.isEmpty ||
          id.contains(query) ||
          customer.contains(query) ||
          restaurant.contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  double _money(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Unknown date';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showOrder(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: HalalFoodTheme.primaryGreen.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: HalalFoodTheme.primaryGreen),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '#${_shortId(order['id']?.toString() ?? '')}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _StatusBadge(status: status, color: _statusColor(status)),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailRow('Customer ID', order['customer_id']?.toString() ?? 'Unknown'),
                _DetailRow('Restaurant ID', order['restaurant_id']?.toString() ?? 'Unknown'),
                _DetailRow('Payment', _displayStatus(order['payment_status']?.toString() ?? 'pending')),
                _DetailRow('Placed', _formatDate(order['created_at'])),
                if ((order['notes']?.toString() ?? '').trim().isNotEmpty)
                  _DetailRow('Notes', order['notes'].toString()),
                const Divider(height: 26),
                _MoneyRow('Subtotal', _money(order['subtotal'])),
                _MoneyRow('Delivery Fee', _money(order['delivery_fee'])),
                const SizedBox(height: 8),
                _MoneyRow('Total', _money(order['total_amount']), isTotal: true),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Order Management', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _loading ? null : _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _loading
            ? const ListView(children: [SizedBox(height: 260), Center(child: CircularProgressIndicator())])
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadOrders)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _OverviewCard(orders: _orders),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _search = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search order, customer or restaurant ID...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _search = '');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final item in _statusFilters)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(item.$1),
                                  selected: _filter == item.$2,
                                  onSelected: (_) => setState(() => _filter = item.$2),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${orders.length} order${orders.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: HalalFoodTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      if (orders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('No orders found.')),
                        )
                      else
                        ...orders.map((order) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OrderCard(order: order, onTap: () => _showOrder(order)),
                            )),
                    ],
                  ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _OverviewCard({required this.orders});

  int count(String status) => orders.where((order) {
        final value = order['status']?.toString().toLowerCase() ?? 'pending';
        if (status == 'pending') return value == 'pending' || value == 'placed' || value == 'order_placed';
        if (status == 'active') return !{'delivered', 'completed', 'cancelled', 'canceled', 'refunded'}.contains(value);
        return value == status;
      }).length;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Monitor incoming orders from one place.', style: TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Metric('Total', orders.length.toString(), Icons.receipt_long_rounded)),
                Expanded(child: _Metric('Pending', count('pending').toString(), Icons.pending_actions_rounded)),
                Expanded(child: _Metric('Active', count('active').toString(), Icons.local_shipping_rounded)),
                Expanded(child: _Metric('Delivered', count('delivered').toString(), Icons.check_circle_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 20, color: HalalFoodTheme.primaryGreen),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10, color: HalalFoodTheme.textSecondary)),
        ],
      );
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  String _status(String value) {
    switch (value.toLowerCase()) {
      case 'placed':
      case 'order_placed':
        return 'pending';
      case 'accepted':
        return 'confirmed';
      case 'in_preparation':
        return 'preparing';
      case 'ready_for_pickup':
        return 'ready';
      case 'on_the_way':
      case 'out_for_pickup':
        return 'out_for_delivery';
      case 'completed':
        return 'delivered';
      case 'canceled':
        return 'cancelled';
      default:
        return value;
    }
  }

  Color _color(String value) {
    switch (_status(value)) {
      case 'confirmed': return Colors.blue;
      case 'preparing':
      case 'ready':
      case 'out_for_delivery': return Colors.orange;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return HalalFoodTheme.primaryGreen;
    }
  }

  double _money(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Unknown date';
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final id = order['id']?.toString() ?? '';
    final status = _status(order['status']?.toString() ?? 'pending');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HalalFoodTheme.primaryGreen.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: HalalFoodTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(_date(order['created_at']), style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: status, color: _color(status)),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: _SmallInfo(icon: Icons.person_outline_rounded, label: 'Customer', value: _short(order['customer_id']))),
                  Expanded(child: _SmallInfo(icon: Icons.restaurant_outlined, label: 'Restaurant', value: _short(order['restaurant_id']))),
                  Expanded(child: _SmallInfo(icon: Icons.payments_outlined, label: 'Total', value: '₱${_money(order['total_amount']).toStringAsFixed(2)}')),
                ],
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('View order details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HalalFoodTheme.primaryGreen)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: HalalFoodTheme.primaryGreen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _short(dynamic value) {
    final text = value?.toString() ?? '-';
    return text.length > 8 ? '${text.substring(0, 8)}…' : text;
  }
}

class _SmallInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SmallInfo({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: HalalFoodTheme.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: HalalFoodTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  String _label() => status.replaceAll('_', ' ').split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
        child: Text(_label(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;
  const _MoneyRow(this.label, this.value, {this.isTotal = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500))),
          Text('₱${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700, fontSize: isTotal ? 16 : 13)),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
          const SizedBox(height: 14),
          const Text('Unable to load orders', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      );
}
