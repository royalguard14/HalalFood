import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_order_details_screen.dart';
import 'owner_menu_management_screen.dart';
import 'owner_restaurant_profile_screen.dart';
import 'owner_restaurant_selection_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../app/theme.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  
  const OwnerDashboardScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoggingOut = false;
  bool _isLoading = true;
  String? _error;
  String _restaurantName = '';

  int _newOrders = 0;
  int _preparingOrders = 0;
  int _readyOrders = 0;
  int _completedOrders = 0;
  int _monthlyOrders = 0;
  double _todaySales = 0;
  double _monthlySales = 0;
  double _averageRating = 0;
  int _reviewCount = 0;

  String _subscriptionStatus = 'none';
  String _subscriptionPlan = 'No active plan';
  String _subscriptionEnd = '';
  String _subscriptionBilling = '';

  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _topItems = [];
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _reviewsChannel;

  @override
  void initState() {
    super.initState();
    _restaurantName = widget.restaurantName;
    _loadDashboard();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _reviewsChannel?.unsubscribe();
    super.dispose();
  }

  DateTime _monthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to logout: $e')),
      );
    }
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _refreshDashboardData();
      await _refreshSubscription();
      _subscribeToOrders();
      _subscribeToReviews();
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _subscribeToOrders() {
    _ordersChannel?.unsubscribe();
    _ordersChannel = _supabase
        .channel('owner-dashboard-orders-${widget.restaurantId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: widget.restaurantId,
          ),
          callback: (_) => _refreshDashboardData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: widget.restaurantId,
          ),
          callback: (_) => _refreshDashboardData(),
        )
        .subscribe();
  }

  void _subscribeToReviews() {
    _reviewsChannel?.unsubscribe();
    _reviewsChannel = _supabase
        .channel('owner-dashboard-reviews-${widget.restaurantId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: widget.restaurantId,
          ),
          callback: (_) => _refreshDashboardData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: widget.restaurantId,
          ),
          callback: (_) => _refreshDashboardData(),
        )
        .subscribe();
  }

  Future<void> _refreshDashboardData() async {
    final ordersResponse = await _supabase
        .from('orders')
        .select(
          'id, customer_id, status, payment_status, subtotal, delivery_fee, total_amount, created_at',
        )
        .eq('restaurant_id', widget.restaurantId)
        .order('created_at', ascending: false);

    final orders = (ordersResponse as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    int newOrders = 0;
    int preparingOrders = 0;
    int readyOrders = 0;
    int completedOrders = 0;
    int monthlyOrders = 0;
    double todaySales = 0;
    double monthlySales = 0;
    final now = DateTime.now();
    final monthStart = _monthStart();

    final monthlyCompletedOrderIds = <String>[];

    for (final order in orders) {
      final status = order['status']?.toString().toLowerCase() ?? '';
      switch (status) {
        case 'pending':
          newOrders++;
          break;
        case 'preparing':
          preparingOrders++;
          break;
        case 'ready':
        case 'out_for_delivery':
        case 'on_the_way':
          readyOrders++;
          break;
        case 'delivered':
          completedOrders++;
          break;
      }

      final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
      if (createdAt == null) continue;

      final isThisMonth =
          createdAt.year == monthStart.year && createdAt.month == monthStart.month;
      final isToday =
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;

      if (isThisMonth) monthlyOrders++;

      if (status == 'delivered' && isThisMonth) {
        final orderId = order['id']?.toString();
        if (orderId != null) monthlyCompletedOrderIds.add(orderId);
        monthlySales += (order['total_amount'] as num?)?.toDouble() ?? 0;
      }

      if (status == 'delivered' && isToday) {
        todaySales += (order['total_amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final itemTotals = <String, Map<String, dynamic>>{};
    if (monthlyCompletedOrderIds.isNotEmpty) {
      final orderItemsResponse = await _supabase
          .from('order_items')
          .select('menu_item_id, item_name, quantity, subtotal')
          .inFilter('order_id', monthlyCompletedOrderIds);

      for (final row in (orderItemsResponse as List)) {
        final id = row['menu_item_id']?.toString();
        if (id == null) continue;
        final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
        final subtotal = (row['subtotal'] as num?)?.toDouble() ?? 0;
        final current = itemTotals[id];
        if (current == null) {
          itemTotals[id] = {
            'id': id,
            'name': row['item_name']?.toString() ?? 'Menu Item',
            'quantity': quantity,
            'sales': subtotal,
          };
        } else {
          current['quantity'] = (current['quantity'] as int) + quantity;
          current['sales'] = (current['sales'] as double) + subtotal;
        }
      }
    }

    final topItems = itemTotals.values.toList()
      ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

    double averageRating = 0;
    int reviewCount = 0;
    try {
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('rating')
          .eq('restaurant_id', widget.restaurantId);
      final ratings = (reviewsResponse as List)
          .map((row) => (row['rating'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      reviewCount = ratings.length;
      if (ratings.isNotEmpty) {
        averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
      }
    } catch (e) {
      debugPrint('OWNER REVIEW STATS ERROR: $e');
    }

    if (!mounted) return;
    setState(() {
      _newOrders = newOrders;
      _preparingOrders = preparingOrders;
      _readyOrders = readyOrders;
      _completedOrders = completedOrders;
      _monthlyOrders = monthlyOrders;
      _todaySales = todaySales;
      _monthlySales = monthlySales;
      _averageRating = averageRating;
      _reviewCount = reviewCount;
      _recentOrders = orders.take(5).toList();
      _topItems = topItems.take(5).toList();
    });
  }

  Future<void> _refreshSubscription() async {
    try {
      final response = await _supabase
          .from('restaurant_subscriptions')
          .select('status, billing_cycle, current_period_end, subscription_plans(name)')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        setState(() {
          _subscriptionStatus = 'none';
          _subscriptionPlan = 'No active plan';
          _subscriptionEnd = '';
          _subscriptionBilling = '';
        });
        return;
      }

      final plan = response['subscription_plans'];
      final planName = plan is Map
          ? plan['name']?.toString() ?? 'Subscription Plan'
          : 'Subscription Plan';
      final end = DateTime.tryParse(
        response['current_period_end']?.toString() ?? '',
      );

      setState(() {
        _subscriptionStatus = response['status']?.toString() ?? 'active';
        _subscriptionPlan = planName;
        _subscriptionEnd = end == null ? '' : _dateOnly(end);
        _subscriptionBilling = response['billing_cycle']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('OWNER SUBSCRIPTION STATUS ERROR: $e');
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _refreshRestaurantName() async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select('name')
          .eq('id', widget.restaurantId)
          .maybeSingle();
      if (!mounted || response == null) return;
      setState(() => _restaurantName = response['name']?.toString() ?? '');
    } catch (e) {
      debugPrint('OWNER RESTAURANT NAME REFRESH ERROR: $e');
    }
  }

  Future<void> _switchRestaurant() async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OwnerRestaurantSelectionScreen()),
      (route) => false,
    );
  }

  String _shortOrderId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  String _formatStatus(String status) => status
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
      case 'out_for_delivery':
      case 'on_the_way':
        return Colors.deepPurple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return HalalFoodTheme.primaryGreen;
    }
  }

  Color _subscriptionColor() {
    switch (_subscriptionStatus.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'past_due':
        return Colors.orange;
      case 'suspended':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _subscriptionLabel() {
    switch (_subscriptionStatus.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'past_due':
        return 'Past Due';
      case 'suspended':
        return 'Suspended';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'No Subscription';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Restaurant Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Switch Restaurant',
            onPressed: _isLoading ? null : _switchRestaurant,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                ElevatedButton(onPressed: _loadDashboard, child: const Text('Try Again')),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildWelcomeCard(),
        const SizedBox(height: 16),
        _buildSubscriptionCard(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerMenuManagementScreen(
                    restaurantId: widget.restaurantId,
                    restaurantName: _restaurantName,
                  ),
                ),
              );
              if (mounted) await _refreshRestaurantName();
            },
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text('Manage Menu', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerRestaurantProfileScreen(
                    restaurantId: widget.restaurantId,
                    restaurantName: _restaurantName,
                  ),
                ),
              );
              if (mounted) await _refreshRestaurantName();
            },
            icon: const Icon(Icons.storefront_rounded),
            label: const Text('Restaurant Profile', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Business Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(icon: Icons.payments_outlined, title: 'Sales This Month', value: '₱${_monthlySales.toStringAsFixed(0)}', color: HalalFoodTheme.primaryGreen)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.receipt_long_outlined, title: 'Orders This Month', value: '$_monthlyOrders', color: Colors.blue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(icon: Icons.star_rounded, title: 'Rating', value: _reviewCount == 0 ? '—' : _averageRating.toStringAsFixed(1), color: Colors.orange)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.reviews_outlined, title: 'Reviews', value: '$_reviewCount', color: Colors.deepPurple)),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _buildSalesCard(),
        const SizedBox(height: 24),
        const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(icon: Icons.notifications_active_outlined, title: 'New', value: '$_newOrders', color: Colors.orange)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.restaurant_outlined, title: 'Preparing', value: '$_preparingOrders', color: Colors.blue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(icon: Icons.check_circle_outline_rounded, title: 'Ready', value: '$_readyOrders', color: Colors.deepPurple)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.done_all_rounded, title: 'Delivered', value: '$_completedOrders', color: Colors.green)),
          ],
        ),
        const SizedBox(height: 28),
        const Text('Best Sellers This Month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _buildTopItems(),
        const SizedBox(height: 28),
        const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (_recentOrders.isEmpty) _buildEmptyOrders() else ..._recentOrders.map(_buildOrderCard),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome, Restaurant Owner', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_restaurantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HalalFoodTheme.primaryGreen)),
          const SizedBox(height: 6),
          const Text('Track your restaurant performance, orders, sales, and customer feedback.', style: TextStyle(color: HalalFoodTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final color = _subscriptionColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.workspace_premium_rounded, color: color, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subscription', style: TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary)),
                  const SizedBox(height: 3),
                  Text(_subscriptionPlan, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  if (_subscriptionEnd.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('Valid until $_subscriptionEnd', style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
                  ],
                  if (_subscriptionBilling.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('${_subscriptionBilling[0].toUpperCase()}${_subscriptionBilling.substring(1)} billing', style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _subscriptionLabel(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.payments_outlined, size: 28, color: HalalFoodTheme.primaryGreen),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Text("Today's Sales", style: TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary))),
            Text('₱${_todaySales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: HalalFoodTheme.primaryGreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItems() {
    if (_topItems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.trending_up_rounded, size: 46, color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.55)),
              const SizedBox(height: 10),
              const Text('No delivered item sales this month yet.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: _topItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final quantity = item['quantity'] as int;
          final sales = item['sales'] as double;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: index == 0
                      ? Colors.amber.withValues(alpha: 0.16)
                      : HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                title: Text(item['name']?.toString() ?? 'Menu Item', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('$quantity sold this month'),
                trailing: Text(
                  '₱${sales.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (index != _topItems.length - 1) const Divider(height: 1, indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 52, color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.55)),
            const SizedBox(height: 12),
            const Text('No orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Customer orders will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = order['id']?.toString() ?? '';
    final status = order['status']?.toString() ?? 'pending';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OwnerOrderDetailsScreen(order: order)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: HalalFoodTheme.primaryGreen),
        ),
        title: Text('#${_shortOrderId(id)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(_formatStatus(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor(status))),
        trailing: Text('₱${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
