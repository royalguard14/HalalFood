import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';
import '../data/admin_repository.dart';
import 'restaurant_management_screen.dart';
import 'halal_verification_screen.dart';
import 'food_category_management_screen.dart';


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
  });

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
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

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

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

      setState(() {
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
      _pendingVerificationCount =
          results[2] as int;
      _todayOrderCount = results[3] as int;
      _pendingOrderCount = results[4] as int;
      _deliveryPricing =
          results[5] as Map<String, dynamic>?;
    });
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _subscribeToRealtime() {
    _restaurantsChannel?.unsubscribe();
    _ordersChannel?.unsubscribe();

    _restaurantsChannel = _supabase
        .channel('admin-restaurants')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'restaurants',
          callback: (payload) {
            debugPrint(
              'ADMIN REALTIME: RESTAURANT CHANGED',
            );

            _refreshDashboard();
          },
        )
        .subscribe();

    _ordersChannel = _supabase
        .channel('admin-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint(
              'ADMIN REALTIME: ORDER CHANGED',
            );

            _refreshDashboard();
          },
        )
        .subscribe();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to logout: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _money(dynamic value) {
    final amount =
        (value as num?)?.toDouble() ?? 0;

    return '₱${amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoading ? null : _loadDashboard,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed:
                _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.logout_rounded,
                  ),
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
          const SizedBox(height: 150),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 60,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load admin dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        HalalFoodTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _loadDashboard,
                  child: const Text(
                    'Try Again',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        _buildWelcomeCard(),

        const SizedBox(height: 24),

        const Text(
          'Platform Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon:
                    Icons.restaurant_rounded,
                title: 'Restaurants',
                value:
                    _restaurantCount.toString(),
                color:
                    HalalFoodTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon:
                    Icons.check_circle_outline,
                title: 'Active',
                value:
                    _activeRestaurantCount
                        .toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon:
                    Icons.verified_outlined,
                title: 'For Verification',
                value:
                    _pendingVerificationCount
                        .toString(),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon:
                    Icons.receipt_long_outlined,
                title: "Today's Orders",
                value:
                    _todayOrderCount.toString(),
                color: Colors.blue,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _StatCard(
          icon:
              Icons.pending_actions_rounded,
          title: 'Pending Orders',
          value:
              _pendingOrderCount.toString(),
          color: Colors.deepPurple,
        ),

        const SizedBox(height: 28),

        const Text(
          'Admin Tools',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        _buildToolCard(
          icon: Icons.restaurant_rounded,
          title: 'Restaurant Management',
          subtitle:
              'Verify, activate, deactivate and feature restaurants.',
          color:
              HalalFoodTheme.primaryGreen,
   onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          const RestaurantManagementScreen(),
    ),
  );
},
        ),

        const SizedBox(height: 10),

_buildToolCard(
  icon: Icons.verified_rounded,
  title: 'Halal Verification',
  subtitle:
      'Review restaurants and manage their halal certification status.',
  color: Colors.teal,
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const HalalVerificationScreen(),
      ),
    );
  },
),


        const SizedBox(height: 10),

        _buildToolCard(
          icon: Icons.category_rounded,
          title: 'Food Categories',
          subtitle:
              'Create and manage the food categories used by restaurants.',
          color: Colors.orange,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const FoodCategoryManagementScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        _buildToolCard(
          icon:
              Icons.delivery_dining_rounded,
          title: 'Delivery Pricing',
          subtitle:
              'Manage base fee, distance rates and delivery surcharges.',
          color: Colors.blue,
          onTap: () {
            _showDeliveryPricing();
          },
        ),

        const SizedBox(height: 10),

        _buildToolCard(
          icon: Icons.people_alt_outlined,
          title: 'Users & Roles',
          subtitle:
              'Manage platform accounts and assigned roles.',
          color: Colors.deepPurple,
          onTap: () {
            _showComingSoon(
              'Users & Roles',
            );
          },
        ),

        const SizedBox(height: 28),

        const Text(
          'Current Delivery Pricing',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        _buildDeliveryPricingCard(),
      ],
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen
            .withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor:
                HalalFoodTheme.primaryGreen,
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage the HALAL Food platform from here.',
                  style: TextStyle(
                    color:
                        HalalFoodTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOOL CARD
  // ============================================================

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      color.withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            HalalFoodTheme
                                .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DELIVERY PRICING CARD
  // ============================================================

  Widget _buildDeliveryPricingCard() {
    final pricing = _deliveryPricing;

    if (pricing == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No delivery pricing settings found.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _PricingRow(
              label: 'Base Fee',
              value:
                  _money(pricing['base_fee']),
            ),
            _PricingRow(
              label: 'Included Distance',
              value:
                  '${pricing['included_distance_km']} km',
            ),
            _PricingRow(
              label: 'Per KM Rate',
              value:
                  _money(pricing['per_km_rate']),
            ),
            _PricingRow(
              label: 'Minimum Fee',
              value:
                  _money(pricing['minimum_fee']),
            ),
            _PricingRow(
              label: 'Maximum Distance',
              value:
                  '${pricing['maximum_delivery_distance_km']} km',
            ),
            _PricingRow(
              label: 'Rain Surcharge',
              value:
                  _money(pricing['rain_surcharge']),
            ),
            _PricingRow(
              label: 'Peak Hour',
              value:
                  _money(
                pricing['peak_hour_surcharge'],
              ),
            ),
            _PricingRow(
              label: 'Night Surcharge',
              value:
                  _money(
                pricing['night_surcharge'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DELIVERY PRICING PREVIEW
  // ============================================================

  void _showDeliveryPricing() {
    final pricing = _deliveryPricing;

    if (pricing == null) {
      _showComingSoon(
        'Delivery Pricing',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              30,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Pricing',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'These settings control the platform-wide delivery pricing.',
                  style: TextStyle(
                    color:
                        HalalFoodTheme
                            .textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _PricingRow(
                  label: 'Base Fee',
                  value:
                      _money(pricing['base_fee']),
                ),
                _PricingRow(
                  label: 'Included Distance',
                  value:
                      '${pricing['included_distance_km']} km',
                ),
                _PricingRow(
                  label: 'Per KM',
                  value:
                      _money(pricing['per_km_rate']),
                ),
                _PricingRow(
                  label: 'Fuel Adjustment',
                  value:
                      _money(
                    pricing['fuel_adjustment'],
                  ),
                ),
                _PricingRow(
                  label: 'Minimum Fee',
                  value:
                      _money(
                    pricing['minimum_fee'],
                  ),
                ),
                _PricingRow(
                  label: 'Maximum Distance',
                  value:
                      '${pricing['maximum_delivery_distance_km']} km',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );

                      _showComingSoon(
                        'Delivery Pricing Editor',
                      );
                    },
                    icon: const Icon(
                      Icons.edit_rounded,
                    ),
                    label: const Text(
                      'Edit Pricing',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature module will be connected next.',
        ),
      ),
    );
  }
}

// ============================================================
// STAT CARD
// ============================================================

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
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    color.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 20,
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

// ============================================================
// PRICING ROW
// ============================================================

class _PricingRow extends StatelessWidget {
  final String label;
  final String value;

  const _PricingRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
