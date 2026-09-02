import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase.dart';
import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';
import '../data/admin_repository.dart';
import 'admin_action_center_screen.dart';
import 'admin_menu_management_screen.dart';
import 'admin_order_management_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_saas_subscription_hub_screen.dart';
import 'delivery_pricing_screen.dart';
import 'food_category_management_screen.dart';
import 'halal_verification_screen.dart';
import 'promo_management_screen.dart';
import 'restaurant_management_screen.dart';
import 'user_role_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
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
  int _pendingPaymentCount = 0;
  int _todayOrderCount = 0;
  int _pendingOrderCount = 0;
  RealtimeChannel? _restaurantsChannel;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _verificationChannel;
  RealtimeChannel? _paymentChannel;

  int get _actionCount => _pendingVerificationCount + _pendingPaymentCount;

  @override
  void initState() { super.initState(); _loadDashboard(); }

  @override
  void dispose() {
    _restaurantsChannel?.unsubscribe();
    _ordersChannel?.unsubscribe();
    _verificationChannel?.unsubscribe();
    _paymentChannel?.unsubscribe();
    super.dispose();
  }

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
      _getPendingPaymentCount(),
      _repository.getTodayOrderCount(),
      _repository.getPendingOrderCount(),
    ]);
    if (!mounted) return;
    setState(() {
      _restaurantCount = r[0];
      _activeRestaurantCount = r[1];
      _pendingVerificationCount = r[2];
      _pendingPaymentCount = r[3];
      _todayOrderCount = r[4];
      _pendingOrderCount = r[5];
    });
  }

  Future<int> _getPendingPaymentCount() async {
    final response = await _supabase.from('subscription_payments').select('id').eq('status', 'pending');
    return (response as List).length;
  }

  void _subscribeToRealtime() {
    _restaurantsChannel?.unsubscribe();
    _ordersChannel?.unsubscribe();
    _verificationChannel?.unsubscribe();
    _paymentChannel?.unsubscribe();
    _restaurantsChannel = _supabase.channel('admin-restaurants').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'restaurants', callback: (_) => _refreshDashboard()).subscribe();
    _ordersChannel = _supabase.channel('admin-orders').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'orders', callback: (_) => _refreshDashboard()).subscribe();
    _verificationChannel = _supabase.channel('admin-verifications').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'halal_verifications', callback: (_) => _refreshDashboard()).subscribe();
    _paymentChannel = _supabase.channel('admin-subscription-payments').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'subscription_payments', callback: (_) => _refreshDashboard()).subscribe();
  }

  Future<void> _openActionCenter() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminActionCenterScreen()));
    if (mounted) await _refreshDashboard();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
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

  void _openGroup(_AdminGroup group) {
    if (group.items.length == 1) { group.items.first.onTap(); return; }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _AdminGroupHubScreen(group: group)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F8F7),
    appBar: AppBar(
      elevation: 0, backgroundColor: Colors.white, surfaceTintColor: Colors.white,
      title: const Row(children: [Icon(Icons.admin_panel_settings_rounded), SizedBox(width: 10), Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w800))]),
      actions: [
        Stack(clipBehavior: Clip.none, children: [
          IconButton(tooltip: 'Admin Action Center', onPressed: _isLoading ? null : _openActionCenter, icon: const Icon(Icons.notifications_none_rounded)),
          if (_actionCount > 0) Positioned(right: 5, top: 4, child: IgnorePointer(child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
            alignment: Alignment.center,
            child: Text(_actionCount > 99 ? '99+' : '$_actionCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
          ))),
        ]),
        IconButton(tooltip: 'Admin Profile', onPressed: _isLoading ? null : () => _open(const AdminProfileScreen()), icon: const Icon(Icons.account_circle_rounded)),
        IconButton(tooltip: 'Refresh dashboard', onPressed: _isLoading ? null : _loadDashboard, icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'Logout', onPressed: _isLoggingOut ? null : _logout, icon: _isLoggingOut ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout_rounded)),
      ],
    ),
    body: RefreshIndicator(onRefresh: _loadDashboard, child: _buildBody()),
  );

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 120), const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.redAccent), const SizedBox(height: 16),
      const Text('Unable to load dashboard', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16),
      ElevatedButton(onPressed: _loadDashboard, child: const Text('Try Again')),
    ]);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 22, wide ? 32 : 18, 40), children: [
        _headerCard(wide), const SizedBox(height: 24),
        if (_actionCount > 0) ...[_actionCenterCard(), const SizedBox(height: 24)],
        _sectionTitle('Platform Overview', 'Live summary of your HALAL Food platform'), const SizedBox(height: 12), _stats(wide), const SizedBox(height: 24),
        if (_pendingVerificationCount > 0) ...[_verificationAlert(), const SizedBox(height: 24)],
        _sectionTitle('Admin Tools', 'Choose an area to manage your platform'), const SizedBox(height: 12), _groups(wide),
      ]);
    });
  }

  Widget _actionCenterCard() => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: _openActionCenter, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
    Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.notifications_active_rounded, color: Colors.redAccent, size: 27)),
    const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Action Center', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      SizedBox(height: 5),
      Text('$_actionCount item${_actionCount == 1 ? '' : 's'} need${_actionCount == 1 ? 's' : ''} your attention', style: TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
      SizedBox(height: 3),
      Text('$_pendingVerificationCount halal verification • $_pendingPaymentCount subscription payment${_pendingPaymentCount == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)),
    ])),
    const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.redAccent),
  ])));

  Widget _sectionTitle(String t, String s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(s, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary))]);

  Widget _headerCard(bool wide) => Container(padding: EdgeInsets.all(wide ? 26 : 20), decoration: BoxDecoration(gradient: LinearGradient(colors: [HalalFoodTheme.primaryGreen, HalalFoodTheme.primaryGreen.withValues(alpha: .82)]), borderRadius: BorderRadius.circular(24)), child: const Row(children: [
    Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 42), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Welcome, Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 5),
      Text('Manage restaurants, orders, users, subscriptions, marketing and platform settings.', style: TextStyle(color: Colors.white70, fontSize: 13)),
    ])),
  ]));

  Widget _stats(bool wide) {
    final cards = [
      _DashboardStat(Icons.restaurant_rounded, 'Restaurants', '$_restaurantCount', 'Total registered', HalalFoodTheme.primaryGreen),
      _DashboardStat(Icons.check_circle_rounded, 'Active', '$_activeRestaurantCount', 'Currently visible', Colors.green),
      _DashboardStat(Icons.pending_actions_rounded, 'Verification', '$_pendingVerificationCount', 'Requests to review', Colors.orange),
      _DashboardStat(Icons.receipt_long_rounded, "Today's Orders", '$_todayOrderCount', 'Orders today', Colors.blue),
      _DashboardStat(Icons.local_shipping_rounded, 'Pending Orders', '$_pendingOrderCount', 'Need attention', Colors.deepPurple),
    ];
    if (wide) return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cards.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisExtent: 92, crossAxisSpacing: 12, mainAxisSpacing: 12), itemBuilder: (_, i) => cards[i]);
    return Column(children: [Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]), const SizedBox(height: 10), Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]), const SizedBox(height: 10), cards[4]]);
  }

  Widget _verificationAlert() => Card(color: Colors.orange.withValues(alpha: .08), child: ListTile(leading: const Icon(Icons.priority_high_rounded, color: Colors.orange), title: Text('$_pendingVerificationCount verification request${_pendingVerificationCount == 1 ? '' : 's'} waiting', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Review submitted documents and make the halal classification decision.'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => _open(const HalalVerificationScreen())));

  List<_AdminGroup> get _adminGroups => [
    _AdminGroup(Icons.restaurant_rounded, 'Restaurants & Menu', 'Manage restaurants, menus, categories and halal verification', HalalFoodTheme.primaryGreen, [
      _AdminGroupItem(Icons.restaurant_rounded, 'Restaurant Management', 'Profiles, ownership and restaurant status', () => _open(const RestaurantManagementScreen())),
      _AdminGroupItem(Icons.restaurant_menu_rounded, 'Menu Management', 'Add, edit and manage menu items', () => _open(const AdminMenuManagementScreen())),
      _AdminGroupItem(Icons.category_rounded, 'Food Categories', 'Create and manage food categories', () => _open(const FoodCategoryManagementScreen())),
      _AdminGroupItem(Icons.verified_rounded, 'Halal Verification', 'Review verification requests and classifications', () => _open(const HalalVerificationScreen())),
    ]),
    _AdminGroup(Icons.receipt_long_rounded, 'Orders & Delivery', 'Manage customer orders, delivery fees and operations', Colors.indigo, [
      _AdminGroupItem(Icons.receipt_long_rounded, 'Order Management', 'View and monitor customer orders and status', () => _open(const AdminOrderManagementScreen())),
      _AdminGroupItem(Icons.delivery_dining_rounded, 'Delivery Pricing', 'Delivery fees, distance rates and surcharges', () => _open(const DeliveryPricingScreen())),
    ]),
    _AdminGroup(Icons.people_alt_rounded, 'Users & Accounts', 'Manage platform accounts and assigned roles', Colors.deepPurple, [
      _AdminGroupItem(Icons.people_alt_rounded, 'Users & Roles', 'Manage accounts and assigned roles', () => _open(const UserRoleManagementScreen())),
    ]),
    _AdminGroup(Icons.workspace_premium_rounded, 'Subscription & Billing', 'Manage SaaS plans, subscriptions and payment review', Colors.deepOrange, [
      _AdminGroupItem(Icons.workspace_premium_rounded, 'SaaS Subscriptions', 'Plans, subscriptions and payment review', () => _open(const AdminSaasSubscriptionHubScreen())),
    ]),
    _AdminGroup(Icons.local_offer_rounded, 'Marketing', 'Manage promos, discounts and customer campaigns', Colors.pink, [
      _AdminGroupItem(Icons.local_offer_rounded, 'Promos & Discounts', 'Create promo codes and customer discounts', () => _open(const PromoManagementScreen())),
    ]),
    _AdminGroup(Icons.settings_rounded, 'System Settings', 'Platform configuration and admin controls', Colors.blueGrey, [
      _AdminGroupItem(Icons.settings_rounded, 'My Settings', 'Platform settings and SaaS payment configuration', () => _open(const AdminSettingsScreen())),
    ]),
  ];

  Widget _groups(bool wide) {
    final groups = _adminGroups;
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: groups.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: wide ? 3 : 1, mainAxisExtent: wide ? 118 : 104, crossAxisSpacing: 12, mainAxisSpacing: 12), itemBuilder: (_, i) => _AdminGroupCard(group: groups[i], onTap: () => _openGroup(groups[i])));
  }
}

class _AdminGroup { final IconData icon; final String title; final String subtitle; final Color color; final List<_AdminGroupItem> items; const _AdminGroup(this.icon, this.title, this.subtitle, this.color, this.items); }
class _AdminGroupItem { final IconData icon; final String title; final String subtitle; final VoidCallback onTap; const _AdminGroupItem(this.icon, this.title, this.subtitle, this.onTap); }
class _AdminGroupCard extends StatelessWidget {
  final _AdminGroup group; final VoidCallback onTap;
  const _AdminGroupCard({required this.group, required this.onTap});
  @override Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Container(width: 52, height: 52, decoration: BoxDecoration(color: group.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)), child: Icon(group.icon, color: group.color, size: 27)), const SizedBox(width: 14),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(group.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.25, color: HalalFoodTheme.textSecondary))])), const SizedBox(width: 8), Icon(Icons.arrow_forward_ios_rounded, size: 15, color: group.color),
  ])));
}
class _AdminGroupHubScreen extends StatelessWidget {
  final _AdminGroup group;
  const _AdminGroupHubScreen({required this.group});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFFF6F8F7), appBar: AppBar(elevation: 0, backgroundColor: Colors.white, surfaceTintColor: Colors.white, title: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800))), body: ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 32), children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: group.color.withValues(alpha: .08), borderRadius: BorderRadius.circular(20), border: Border.all(color: group.color.withValues(alpha: .12))), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: group.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: Icon(group.icon, color: group.color, size: 27)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(group.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(group.subtitle, style: const TextStyle(fontSize: 12, height: 1.35, color: HalalFoodTheme.textSecondary))]))])),
    const SizedBox(height: 22), const Text('Management Sections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
    ...group.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: item.onTap, child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: group.color.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: group.color, size: 23)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.3, color: HalalFoodTheme.textSecondary))])), const SizedBox(width: 8), Icon(Icons.arrow_forward_ios_rounded, size: 15, color: group.color)]))))),
  ]));
}
class _DashboardStat extends StatelessWidget {
  final IconData icon; final String title; final String value; final String caption; final Color color;
  const _DashboardStat(this.icon, this.title, this.value, this.caption, this.color);
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Row(children: [Icon(icon, color: color, size: 25), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700))]))]));
}
