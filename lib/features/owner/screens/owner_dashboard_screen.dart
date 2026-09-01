import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_menu_management_screen.dart';
import 'owner_order_details_screen.dart';
import 'owner_restaurant_profile_screen.dart';
import 'owner_restaurant_selection_screen.dart';
import 'owner_subscribe_screen.dart';
import 'owner_subscription_management_screen.dart';
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
  late String _restaurantName;
  bool _loading = true;
  bool _loggingOut = false;
  String? _subscriptionStatus;
  String? _subscriptionPlan;
  String? _subscriptionExpiry;
  double _monthlySales = 0;
  int _monthlyOrders = 0;
  double _todaySales = 0;
  int _newOrders = 0;
  int _preparingOrders = 0;
  int _readyOrders = 0;
  int _completedOrders = 0;
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _restaurantName = widget.restaurantName;
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    await Future.wait([
      _loadSubscription(),
      _loadBusinessStats(),
      _loadOrderStats(),
      _loadRestaurantName(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSubscription() async {
    try {
      final subscription = await _supabase
          .from('restaurant_subscriptions')
          .select('status,current_period_end,billing_cycle,subscription_plans(name)')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      final plan = subscription?['subscription_plans'];
      setState(() {
        _subscriptionStatus = subscription?['status']?.toString();
        _subscriptionPlan = plan is Map ? plan['name']?.toString() : null;
        _subscriptionExpiry = subscription?['current_period_end']?.toString();
      });
    } catch (e) {
      debugPrint('OWNER SUBSCRIPTION ERROR: $e');
    }
  }

  Future<void> _loadRestaurantName() async {
    try {
      final restaurant = await _supabase
          .from('restaurants')
          .select('name')
          .eq('id', widget.restaurantId)
          .maybeSingle();
      if (!mounted || restaurant == null) return;
      setState(() => _restaurantName = restaurant['name']?.toString() ?? _restaurantName);
    } catch (e) {
      debugPrint('OWNER RESTAURANT ERROR: $e');
    }
  }

  Future<void> _loadBusinessStats() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final orders = await _supabase
          .from('orders')
          .select('id,total_amount,created_at,status')
          .eq('restaurant_id', widget.restaurantId)
          .gte('created_at', monthStart);

      double sales = 0;
      int delivered = 0;
      for (final row in orders as List) {
        final status = row['status']?.toString();
        if (status == 'delivered' || status == 'completed') {
          sales += (row['total_amount'] as num?)?.toDouble() ?? 0;
          delivered++;
        }
      }

      if (!mounted) return;
      setState(() {
        _monthlySales = sales;
        _monthlyOrders = delivered;
      });
    } catch (e) {
      debugPrint('OWNER BUSINESS ERROR: $e');
    }
  }

  Future<void> _loadOrderStats() async {
    try {
      final rows = await _supabase
          .from('orders')
          .select('id,total_amount,created_at,status')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false)
          .limit(20);

      int newOrders = 0;
      int preparing = 0;
      int ready = 0;
      int completed = 0;
      double todaySales = 0;
      final today = DateTime.now();

      for (final row in rows as List) {
        final status = row['status']?.toString() ?? '';
        if (status == 'pending' || status == 'confirmed') newOrders++;
        if (status == 'preparing') preparing++;
        if (status == 'ready') ready++;
        if (status == 'delivered' || status == 'completed') completed++;

        final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
        if (created != null &&
            created.year == today.year &&
            created.month == today.month &&
            created.day == today.day &&
            (status == 'delivered' || status == 'completed')) {
          todaySales += (row['total_amount'] as num?)?.toDouble() ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _newOrders = newOrders;
        _preparingOrders = preparing;
        _readyOrders = ready;
        _completedOrders = completed;
        _todaySales = todaySales;
        _recentOrders = rows.cast<Map<String, dynamic>>().take(5).toList();
      });
    } catch (e) {
      debugPrint('OWNER ORDER ERROR: $e');
    }
  }

  String _formatDate(String? value) {
    if (value == null) return 'Not set';
    final date = DateTime.tryParse(value);
    if (date == null) return 'Not set';
    return '${date.month}/${date.day}/${date.year}';
  }

  bool get _hasActivePlan =>
      _subscriptionStatus == 'active' || _subscriptionStatus == 'trial';

  Future<void> _openSubscription() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerSubscriptionManagementScreen(
          restaurantId: widget.restaurantId,
          restaurantName: _restaurantName,
        ),
      ),
    );
    if (mounted) await _loadDashboard();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _switchRestaurant() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OwnerRestaurantSelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Owner Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Switch Restaurant',
            onPressed: _loading ? null : _switchRestaurant,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
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
        child: _loading ? _buildLoading() : _buildDashboard(),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 280),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildDashboard() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildWelcomeCard(),
        const SizedBox(height: 16),
        _buildSubscriptionCard(),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerSubscribeScreen(
                    restaurantId: widget.restaurantId,
                    restaurantName: _restaurantName,
                  ),
                ),
              );
              if (mounted) await _refreshSubscription();
            },
            icon: const Icon(Icons.workspace_premium_rounded),
            label: Text(_subscriptionStatus == 'active' ? 'Manage Subscription' : 'Choose Subscription Plan', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                Icons.restaurant_menu_rounded,
                'Menu Items',
                '—',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                Icons.receipt_long_rounded,
                'Open Orders',
                '${_newOrders + _preparingOrders + _readyOrders}',
              ),
            ),
          ],
        ),
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
              if (mounted) await _loadDashboard();
            },
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text(
              'Manage Menu',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
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
              if (mounted) await _loadDashboard();
            },
            icon: const Icon(Icons.storefront_rounded),
            label: const Text(
              'Restaurant Profile',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Business Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                Icons.payments_outlined,
                'Sales This Month',
                '₱${_monthlySales.toStringAsFixed(0)}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                Icons.receipt_long_outlined,
                'Orders This Month',
                '$_monthlyOrders',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Today',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _buildSalesCard(),
        const SizedBox(height: 24),
        const Text(
          'Order Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard(Icons.notifications_active_outlined, 'New', '$_newOrders')),
            const SizedBox(width: 10),
            Expanded(child: _statCard(Icons.restaurant_outlined, 'Preparing', '$_preparingOrders')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statCard(Icons.check_circle_outline_rounded, 'Ready', '$_readyOrders')),
            const SizedBox(width: 10),
            Expanded(child: _statCard(Icons.done_all_rounded, 'Delivered', '$_completedOrders')),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Best Sellers This Month',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _buildTopItems(),
        const SizedBox(height: 28),
        const Text(
          'Recent Orders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_recentOrders.isEmpty)
          _buildEmptyOrders()
        else
          ..._recentOrders.map(_buildOrderCard),
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
          const Text(
            'Welcome, Restaurant Owner',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _restaurantName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track your restaurant performance, orders, sales, and customer feedback.',
            style: TextStyle(color: HalalFoodTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final active = _hasActivePlan;
    final color = active ? Colors.green : Colors.grey;
    final status = _subscriptionStatus == null
        ? 'NO ACTIVE PLAN'
        : _subscriptionStatus!.toUpperCase().replaceAll('_', ' ');

    return Card(
      child: InkWell(
        onTap: _openSubscription,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscription',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    if (_subscriptionPlan != null)
                      Text(_subscriptionPlan!),
                    if (_subscriptionExpiry != null)
                      Text('Expires: ${_formatDate(_subscriptionExpiry)}'),
                    if (!active)
                      const Text(
                        'Tap to choose a plan',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
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
              child: const Icon(
                Icons.payments_outlined,
                size: 28,
                color: HalalFoodTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "Today's Sales",
                style: TextStyle(
                  fontSize: 13,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
            ),
            Text(
              '₱${_todaySales.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: HalalFoodTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItems() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 46,
              color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            const Text(
              'No delivered item sales this month yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            const Text(
              'No orders yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Customer orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = order['id']?.toString() ?? '';
    final status = order['status']?.toString() ?? 'pending';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final shortId = id.length <= 8 ? id : id.substring(0, 8);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OwnerOrderDetailsScreen(order: order),
            ),
          );
        },
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: HalalFoodTheme.primaryGreen,
          ),
        ),
        title: Text(
          '#$shortId',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        trailing: Text(
          '₱${total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: HalalFoodTheme.primaryGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HalalFoodTheme.textSecondary,
                      fontSize: 12,
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
