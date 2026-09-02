import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';
import '../data/admin_repository.dart';
import 'admin_menu_management_screen.dart';
import 'admin_order_management_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_subscription_management_screen.dart';
import 'delivery_pricing_screen.dart';
import 'food_category_management_screen.dart';
import 'halal_verification_screen.dart';
import 'promo_management_screen.dart';
import 'restaurant_management_screen.dart';
import 'user_role_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repository = AdminRepository();
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _error;
  int _restaurantCount = 0;
  int _activeRestaurantCount = 0;
  int _pendingVerificationCount = 0;
  int _todayOrderCount = 0;
  int _pendingOrderCount = 0;
  RealtimeChannel? _restaurantsChannel;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() { super.initState(); _loadDashboard(); }
  @override
  void dispose() { _restaurantsChannel?.unsubscribe(); _ordersChannel?.unsubscribe(); super.dispose(); }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await _refreshDashboard();
      _subscribeToRealtime();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _refreshDashboard() async {
    final r = await Future.wait([
      _repository.getRestaurantCount(),
      _repository.getActiveRestaurantCount(),
      _repository.getPendingVerificationCount(),
      _repository.getTodayOrderCount(),
      _repository.getPendingOrderCount(),
    ]);
    if (!mounted) return;
    setState(() {
      _restaurantCount = r[0];
      _activeRestaurantCount = r[1];
      _pendingVerificationCount = r[2];
      _todayOrderCount = r[3];
      _pendingOrderCount = r[4];
    });
  }

  void _subscribeToRealtime() {
    _restaurantsChannel?.unsubscribe();
    _ordersChannel?.unsubscribe();
    _restaurantsChannel = _supabase.channel('admin-restaurants').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'restaurants',
      callback: (_) => _refreshDashboard(),
    ).subscribe();
    _ordersChannel = _supabase.channel('admin-orders').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      callback: (_) => _refreshDashboard(),
    ).subscribe();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      _message('Unable to logout: $e');
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refreshDashboard();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F8F7),
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Row(children: [
        Icon(Icons.admin_panel_settings_rounded), SizedBox(width: 10),
        Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
      ]),
      actions: [
        IconButton(tooltip: 'Admin Profile', onPressed: _isLoading ? null : () => _open(const AdminProfileScreen()), icon: const Icon(Icons.account_circle_rounded)),
        IconButton(tooltip: 'Refresh dashboard', onPressed: _isLoading ? null : _loadDashboard, icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'Logout', onPressed: _isLoggingOut ? null : _logout, icon: _isLoggingOut ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout_rounded)),
      ],
    ),
    body: RefreshIndicator(onRefresh: _loadDashboard, child: _buildBody()),
  );

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text('Unable to load dashboard', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadDashboard, child: const Text('Try Again')),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 22, wide ? 32 : 18, 40),
        children: [
          _headerCard(wide), const SizedBox(height: 24),
          _sectionTitle('Platform Overview', 'Live summary of your HALAL Food platform'), const SizedBox(height: 12),
          _stats(wide), const SizedBox(height: 24),
          if (_pendingVerificationCount > 0) ...[_verificationAlert(), const SizedBox(height: 24)],
          _sectionTitle('Admin Tools', 'Quick access to the areas you manage most'), const SizedBox(height: 12),
          _tools(wide),
        ],
      );
    });
  }

  Widget _sectionTitle(String t, String s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
    const SizedBox(height: 3), Text(s, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
  ]);

  Widget _headerCard(bool wide) => Container(
    padding: EdgeInsets.all(wide ? 26 : 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [HalalFoodTheme.primaryGreen, HalalFoodTheme.primaryGreen.withValues(alpha: .82)]),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Row(children: [
      Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 42), SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome, Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        SizedBox(height: 5),
        Text('Manage restaurants, verification, promos, delivery pricing, subscriptions and platform settings.', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _stats(bool wide) {
    final cards = [
      _DashboardStat(Icons.restaurant_rounded, 'Restaurants', '$_restaurantCount', 'Total registered', HalalFoodTheme.primaryGreen),
      _DashboardStat(Icons.check_circle_rounded, 'Active', '$_activeRestaurantCount', 'Currently visible', Colors.green),
      _DashboardStat(Icons.pending_actions_rounded, 'Verification', '$_pendingVerificationCount', 'Requests to review', Colors.orange),
      _DashboardStat(Icons.receipt_long_rounded, "Today's Orders", '$_todayOrderCount', 'Orders today', Colors.blue),
      _DashboardStat(Icons.local_shipping_rounded, 'Pending Orders', '$_pendingOrderCount', 'Need attention', Colors.deepPurple),
    ];
    if (wide) return Wrap(spacing: 12, runSpacing: 12, children: cards.map((x) => SizedBox(width: 220, child: x)).toList());
    return Column(children: [
      Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]), const SizedBox(height: 10),
      Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]), const SizedBox(height: 10), cards[4],
    ]);
  }

  Widget _verificationAlert() => Card(
    color: Colors.orange.withValues(alpha: .08),
    child: ListTile(
      leading: const Icon(Icons.priority_high_rounded, color: Colors.orange),
      title: Text('$_pendingVerificationCount verification request${_pendingVerificationCount == 1 ? '' : 's'} waiting', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: const Text('Review submitted documents and make the halal classification decision.'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _open(const HalalVerificationScreen()),
    ),
  );

  Widget _tools(bool wide) {
    final tools = [
      _AdminTool(Icons.restaurant_rounded, 'Restaurant Management', 'Manage restaurant profiles, ownership and status.', HalalFoodTheme.primaryGreen, () => _open(const RestaurantManagementScreen())),
      _AdminTool(Icons.restaurant_menu_rounded, 'Menu Management', 'Add, edit and manage menu items for each restaurant.', Colors.green, () => _open(const AdminMenuManagementScreen())),
      _AdminTool(Icons.receipt_long_rounded, 'Order Management', 'View and monitor customer orders and their status.', Colors.indigo, () => _open(const AdminOrderManagementScreen())),
      _AdminTool(Icons.workspace_premium_rounded, 'SaaS Subscriptions', 'Plans, restaurant subscriptions, payment review and plan payment settings.', Colors.deepOrange, () => _open(const AdminSubscriptionManagementScreen())),
      _AdminTool(Icons.verified_rounded, 'Halal Verification', 'Review verification requests and classifications.', Colors.teal, () => _open(const HalalVerificationScreen())),
      _AdminTool(Icons.category_rounded, 'Food Categories', 'Create and manage food categories.', Colors.orange, () => _open(const FoodCategoryManagementScreen())),
      _AdminTool(Icons.local_offer_rounded, 'Promos & Discounts', 'Create promo codes and manage customer discounts.', Colors.pink, () => _open(const PromoManagementScreen())),
      _AdminTool(Icons.delivery_dining_rounded, 'Delivery Pricing', 'Manage delivery fees, distance rates and surcharges.', Colors.blue, () => _open(const DeliveryPricingScreen())),
      _AdminTool(Icons.people_alt_rounded, 'Users & Roles', 'Manage platform accounts and assigned roles.', Colors.deepPurple, () => _open(const UserRoleManagementScreen())),
      _AdminTool(Icons.settings_rounded, 'My Settings', 'Platform settings and SaaS configuration, including payment methods.', Colors.blueGrey, () => _open(const AdminSettingsScreen())),
    ];
    if (wide) return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 460, mainAxisExtent: 118, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemBuilder: (_, i) => tools[i],
    );
    return Column(children: [for (var i = 0; i < tools.length; i++) ...[tools[i], if (i != tools.length - 1) const SizedBox(height: 10)]]);
  }
}

class _DashboardStat extends StatelessWidget {
  final IconData icon; final String title; final String value; final String caption; final Color color;
  const _DashboardStat(this.icon, this.title, this.value, this.caption, this.color);
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Icon(icon, color: color, size: 28), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)), const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(caption, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      ])),
    ]),
  ));
}

class _AdminTool extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Color color; final VoidCallback onTap;
  const _AdminTool(this.icon, this.title, this.subtitle, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.3, color: HalalFoodTheme.textSecondary)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 15, color: color),
      ]),
    )),
  );
}
