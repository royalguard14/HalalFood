import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_order_details_screen.dart';
import 'owner_menu_management_screen.dart';
import 'owner_restaurant_profile_screen.dart';
import 'owner_restaurant_selection_screen.dart';
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
  String? _subscriptionStatus;
  String? _subscriptionPlan;
  String? _subscriptionExpiry;
  int _menuCount = 0;
  int _pendingOrders = 0;

  @override
  void initState() {
    super.initState();
    _restaurantName = widget.restaurantName;
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final subscription = await _supabase
          .from('restaurant_subscriptions')
          .select('status,current_period_end,subscription_plans(name)')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final menu = await _supabase
          .from('menu_items')
          .select('id')
          .eq('restaurant_id', widget.restaurantId);

      final orders = await _supabase
          .from('orders')
          .select('id')
          .eq('restaurant_id', widget.restaurantId)
          .inFilter('status', ['pending', 'confirmed', 'preparing', 'ready']);

      if (!mounted) return;
      final plan = subscription?['subscription_plans'];
      setState(() {
        _subscriptionStatus = subscription?['status']?.toString();
        _subscriptionPlan = plan is Map ? plan['name']?.toString() : null;
        _subscriptionExpiry = subscription?['current_period_end']?.toString();
        _menuCount = (menu as List).length;
        _pendingOrders = (orders as List).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(_restaurantName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Manage your restaurant', style: TextStyle(color: HalalFoodTheme.textSecondary)),
            const SizedBox(height: 16),
            _buildSubscriptionCard(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _statCard(Icons.restaurant_menu_rounded, 'Menu Items', '$_menuCount')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.receipt_long_rounded, 'Open Orders', '$_pendingOrders')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OwnerSubscriptionManagementScreen(
                      restaurantId: widget.restaurantId,
                      restaurantName: _restaurantName,
                    ),
                  ));
                  if (mounted) await _loadDashboard();
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Subscription', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OwnerMenuManagementScreen(
                      restaurantId: widget.restaurantId,
                      restaurantName: _restaurantName,
                    ),
                  ));
                  if (mounted) await _loadDashboard();
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
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OwnerRestaurantProfileScreen(
                      restaurantId: widget.restaurantId,
                      restaurantName: _restaurantName,
                    ),
                  ));
                  if (mounted) await _loadDashboard();
                },
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Restaurant Profile', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OwnerRestaurantSelectionScreen(
                    currentRestaurantId: widget.restaurantId,
                  ),
                ));
              },
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Switch Restaurant'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () async {
                await _supabase.auth.signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final active = _hasActivePlan;
    final status = _subscriptionStatus?.toUpperCase().replaceAll('_', ' ') ?? 'NO ACTIVE PLAN';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (active ? Colors.green : Colors.grey).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.workspace_premium_rounded, color: active ? Colors.green : Colors.grey),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subscription', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(status, style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.green : Colors.grey)),
                  if (_subscriptionPlan != null) Text(_subscriptionPlan!),
                  if (_subscriptionExpiry != null) Text('Expires: ${_formatDate(_subscriptionExpiry)}'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Manage subscription',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OwnerSubscriptionManagementScreen(
                    restaurantId: widget.restaurantId,
                    restaurantName: _restaurantName,
                  ),
                ));
                if (mounted) await _loadDashboard();
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
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
            Icon(icon, size: 28, color: HalalFoodTheme.primaryGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(label, style: TextStyle(color: HalalFoodTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
