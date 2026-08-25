import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';
import '../data/admin_repository.dart';
import 'food_category_management_screen.dart';
import 'halal_verification_screen.dart';
import 'restaurant_management_screen.dart';

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

  Map<String, dynamic>? _deliveryPricing;

  RealtimeChannel? _restaurantsChannel;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _restaurantsChannel?.unsubscribe();
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _refreshDashboard();
      _subscribeToRealtime();

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

  Future<void> _refreshDashboard() async {
    final results = await Future.wait([
      _repository.getRestaurantCount(),
      _repository.getActiveRestaurantCount(),
      _repository.getPendingVerificationCount(),
      _repository.getTodayOrderCount(),
      _repository.getPendingOrderCount(),
      _repository.getDeliveryPricing(),
    ]);

    if (!mounted) return;

    setState(() {
      _restaurantCount = results[0] as int;
      _activeRestaurantCount = results[1] as int;
      _pendingVerificationCount = results[2] as int;
      _todayOrderCount = results[3] as int;
      _pendingOrderCount = results[4] as int;
      _deliveryPricing = results[5] as Map<String, dynamic>?;
    });
  }

  void _subscribeToRealtime() {
    _restaurantsChannel?.unsubscribe();
    _ordersChannel?.unsubscribe();

    _restaurantsChannel = _supabase
        .channel('admin-restaurants')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'restaurants',
          callback: (_) => _refreshDashboard(),
        )
        .subscribe();

    _ordersChannel = _supabase
        .channel('admin-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _refreshDashboard(),
        )
        .subscribe();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to logout: $e')),
      );
    }
  }

  String _money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded),
            SizedBox(width: 10),
            Text(
              'Admin Dashboard',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
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
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 34,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Unable to load dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: HalalFoodTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 22, wide ? 32 : 18, 40),
          children: [
            _buildHeaderCard(wide),
            const SizedBox(height: 24),
            _sectionTitle('Platform Overview', 'Live summary of your HALAL Food platform'),
            const SizedBox(height: 12),
            _buildStatsGrid(wide),
            const SizedBox(height: 24),
            if (_pendingVerificationCount > 0) ...[
              _buildVerificationAlert(),
              const SizedBox(height: 24),
            ],
            _sectionTitle('Admin Tools', 'Quick access to the areas you manage most'),
            const SizedBox(height: 12),
            _buildToolsGrid(wide),
            const SizedBox(height: 24),
            _sectionTitle('Delivery Pricing', 'Current platform-wide delivery settings'),
            const SizedBox(height: 12),
            _buildDeliveryPricingCard(),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(bool wide) {
    return Container(
      padding: EdgeInsets.all(wide ? 26 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HalalFoodTheme.primaryGreen,
            HalalFoodTheme.primaryGreen.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: wide ? 66 : 58,
            height: wide ? 66 : 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Monitor restaurants, halal verification, orders and platform settings from one place.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool wide) {
    final cards = [
      _DashboardStat(
        icon: Icons.restaurant_rounded,
        title: 'Restaurants',
        value: '$_restaurantCount',
        caption: 'Total registered',
        color: HalalFoodTheme.primaryGreen,
      ),
      _DashboardStat(
        icon: Icons.check_circle_rounded,
        title: 'Active',
        value: '$_activeRestaurantCount',
        caption: 'Currently visible',
        color: Colors.green,
      ),
      _DashboardStat(
        icon: Icons.pending_actions_rounded,
        title: 'Verification',
        value: '$_pendingVerificationCount',
        caption: 'Requests to review',
        color: Colors.orange,
      ),
      _DashboardStat(
        icon: Icons.receipt_long_rounded,
        title: "Today's Orders",
        value: '$_todayOrderCount',
        caption: 'Orders today',
        color: Colors.blue,
      ),
      _DashboardStat(
        icon: Icons.local_shipping_rounded,
        title: 'Pending Orders',
        value: '$_pendingOrderCount',
        caption: 'Need attention',
        color: Colors.deepPurple,
      ),
    ];

    if (wide) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((card) => SizedBox(width: 220, child: card))
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 10),
            Expanded(child: cards[3]),
          ],
        ),
        const SizedBox(height: 10),
        cards[4],
      ],
    );
  }

  Widget _buildVerificationAlert() {
    return Material(
      color: Colors.orange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HalalVerificationScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.priority_high_rounded, color: Colors.orange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_pendingVerificationCount verification request${_pendingVerificationCount == 1 ? '' : 's'} waiting',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Review submitted documents and make the halal classification decision.',
                      style: TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(bool wide) {
    final tools = [
      _AdminTool(
        icon: Icons.restaurant_rounded,
        title: 'Restaurant Management',
        subtitle: 'Manage restaurant profiles, ownership, active status and featured listings.',
        color: HalalFoodTheme.primaryGreen,
        onTap: () => _open(const RestaurantManagementScreen()),
      ),
      _AdminTool(
        icon: Icons.verified_rounded,
        title: 'Halal Verification',
        subtitle: 'Review verification requests and maintain approved halal classifications.',
        color: Colors.teal,
        onTap: () => _open(const HalalVerificationScreen()),
      ),
      _AdminTool(
        icon: Icons.category_rounded,
        title: 'Food Categories',
        subtitle: 'Create and manage food categories used across the platform.',
        color: Colors.orange,
        onTap: () => _open(const FoodCategoryManagementScreen()),
      ),
      _AdminTool(
        icon: Icons.delivery_dining_rounded,
        title: 'Delivery Pricing',
        subtitle: 'Review platform delivery fees, distance rates and surcharges.',
        color: Colors.blue,
        onTap: _showDeliveryPricing,
      ),
      _AdminTool(
        icon: Icons.people_alt_rounded,
        title: 'Users & Roles',
        subtitle: 'Manage platform accounts and assigned roles.',
        color: Colors.deepPurple,
        onTap: () => _showComingSoon('Users & Roles'),
      ),
    ];

    if (wide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tools.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 460,
          mainAxisExtent: 118,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (_, index) => tools[index],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < tools.length; i++) ...[
          tools[i],
          if (i != tools.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildDeliveryPricingCard() {
    final pricing = _deliveryPricing;

    if (pricing == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.blue),
              const SizedBox(width: 12),
              const Expanded(child: Text('No delivery pricing settings found.')),
              TextButton(
                onPressed: () => _showComingSoon('Delivery Pricing Editor'),
                child: const Text('Manage'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          children: [
            _PricingRow(label: 'Base Fee', value: _money(pricing['base_fee'])),
            _PricingRow(
              label: 'Included Distance',
              value: '${pricing['included_distance_km'] ?? 0} km',
            ),
            _PricingRow(label: 'Per KM Rate', value: _money(pricing['per_km_rate'])),
            _PricingRow(label: 'Minimum Fee', value: _money(pricing['minimum_fee'])),
            _PricingRow(
              label: 'Maximum Distance',
              value: '${pricing['maximum_delivery_distance_km'] ?? 0} km',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDeliveryPricing,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('View Delivery Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryPricing() {
    final pricing = _deliveryPricing;

    if (pricing == null) {
      _showComingSoon('Delivery Pricing');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery Pricing',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Current platform-wide delivery settings.',
                style: TextStyle(color: HalalFoodTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              _PricingRow(label: 'Base Fee', value: _money(pricing['base_fee'])),
              _PricingRow(
                label: 'Included Distance',
                value: '${pricing['included_distance_km'] ?? 0} km',
              ),
              _PricingRow(label: 'Per KM', value: _money(pricing['per_km_rate'])),
              _PricingRow(label: 'Minimum Fee', value: _money(pricing['minimum_fee'])),
              _PricingRow(
                label: 'Maximum Distance',
                value: '${pricing['maximum_delivery_distance_km'] ?? 0} km',
              ),
              _PricingRow(label: 'Rain Surcharge', value: _money(pricing['rain_surcharge'])),
              _PricingRow(label: 'Peak Hour', value: _money(pricing['peak_hour_surcharge'])),
              _PricingRow(label: 'Night Surcharge', value: _money(pricing['night_surcharge'])),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showComingSoon('Delivery Pricing Editor');
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit Pricing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature module will be connected next.')),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Color color;

  const _DashboardStat({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
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

class _AdminTool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: HalalFoodTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 15, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingRow extends StatelessWidget {
  final String label;
  final String value;

  const _PricingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
