
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_order_details_screen.dart';
import 'owner_menu_management_screen.dart';
import 'owner_restaurant_profile_screen.dart';

import '../../auth/screens/login_screen.dart';
import '../../../app/theme.dart';


class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({
    super.key,
  });

  @override
  State<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState
    extends State<OwnerDashboardScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoggingOut = false;
  bool _isLoading = true;

  String? _error;
  String? _restaurantName;
  String? _restaurantId;

  int _newOrders = 0;
  int _preparingOrders = 0;
  int _readyOrders = 0;
  int _completedOrders = 0;

  double _todaySales = 0;

  List<Map<String, dynamic>> _recentOrders = [];

  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();

    _loadDashboard();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    super.dispose();
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
  // INITIAL DASHBOARD LOAD
  // ============================================================

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'User is not authenticated.',
        );
      }

      final restaurantResponse = await _supabase
          .from('restaurants')
          .select('id, name')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (restaurantResponse == null) {
        throw Exception(
          'No restaurant is linked to this account.',
        );
      }

      final restaurantId =
          restaurantResponse['id'] as String;

      final restaurantName =
          restaurantResponse['name']?.toString() ?? '';

      _restaurantId = restaurantId;

      // Subscribe to realtime only once.
      _subscribeToOrders(restaurantId);

      await _refreshDashboardData(
        restaurantId,
        restaurantName,
      );

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

  // ============================================================
  // REALTIME SUBSCRIPTION
  // ============================================================

  void _subscribeToOrders(
    String restaurantId,
  ) {
    // Prevent duplicate subscriptions.
    _ordersChannel?.unsubscribe();

    debugPrint(
      'OWNER REALTIME: subscribing to restaurant $restaurantId',
    );

    _ordersChannel = _supabase
        .channel(
          'owner-orders-$restaurantId',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (payload) {
            debugPrint(
              'OWNER REALTIME: NEW ORDER RECEIVED',
            );

            _handleRealtimeOrderChange();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (payload) {
            debugPrint(
              'OWNER REALTIME: ORDER UPDATED',
            );

            _handleRealtimeOrderChange();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (payload) {
            debugPrint(
              'OWNER REALTIME: ORDER DELETED',
            );

            _handleRealtimeOrderChange();
          },
        )
        .subscribe(
          (status, error) {
            debugPrint(
              'OWNER REALTIME STATUS: $status',
            );

            if (error != null) {
              debugPrint(
                'OWNER REALTIME ERROR: $error',
              );
            }
          },
        );
  }

  void _handleRealtimeOrderChange() {
    final restaurantId = _restaurantId;

    if (restaurantId == null) {
      return;
    }

    final restaurantName =
        _restaurantName ?? '';

    // Re-read the dashboard data from Supabase.
    // This is NOT a timer and NOT a manual refresh.
    _refreshDashboardData(
      restaurantId,
      restaurantName,
    );
  }

  // ============================================================
  // REFRESH DASHBOARD DATA WITHOUT LOADING SCREEN
  // ============================================================

  Future<void> _refreshDashboardData(
    String restaurantId,
    String restaurantName,
  ) async {
    try {
      final ordersResponse = await _supabase
          .from('orders')
          .select(
            'id, customer_id, status, payment_status, '
            'subtotal, delivery_fee, total_amount, '
            'created_at',
          )
          .eq(
            'restaurant_id',
            restaurantId,
          )
          .order(
            'created_at',
            ascending: false,
          );

      final orders =
          (ordersResponse as List)
              .map(
                (item) =>
                    Map<String, dynamic>.from(item),
              )
              .toList();

      int newOrders = 0;
      int preparingOrders = 0;
      int readyOrders = 0;
      int completedOrders = 0;

      double todaySales = 0;

      final now = DateTime.now();

      for (final order in orders) {
        final status =
            order['status']
                    ?.toString()
                    .toLowerCase() ??
                '';

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

          case 'completed':
            completedOrders++;
            break;
        }

        final createdAtString =
            order['created_at']?.toString();

        if (createdAtString == null) {
          continue;
        }

        final createdAt =
            DateTime.tryParse(createdAtString);

        if (createdAt == null) {
          continue;
        }

        final isToday =
            createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day;

        if (isToday && status == 'completed') {
          todaySales +=
              (order['total_amount'] as num?)
                      ?.toDouble() ??
                  0;
        }
      }

      if (!mounted) return;

      setState(() {
        _restaurantName = restaurantName;

        _newOrders = newOrders;
        _preparingOrders = preparingOrders;
        _readyOrders = readyOrders;
        _completedOrders = completedOrders;

        _todaySales = todaySales;

        _recentOrders =
            orders.take(5).toList();
      });
    } catch (e) {
      debugPrint(
        'OWNER DASHBOARD REFRESH ERROR: $e',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _shortOrderId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(0, 8);
  }

  String _formatStatus(String status) {
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

      case 'completed':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      default:
        return HalalFoodTheme.primaryGreen;
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Restaurant Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
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
                  'Unable to load dashboard',
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
                  onPressed:
                      _loadDashboard,
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
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
_buildWelcomeCard(),

const SizedBox(height: 16),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const OwnerMenuManagementScreen(),
        ),
      );
    },
    icon: const Icon(
      Icons.restaurant_menu_rounded,
    ),
    label: const Text(
      'Manage Menu',
      style: TextStyle(
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
),

const SizedBox(height: 10),

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const OwnerRestaurantProfileScreen(),
        ),
      );
    },
    icon: const Icon(
      Icons.storefront_rounded,
    ),
    label: const Text(
      'Restaurant Profile',
      style: TextStyle(
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
),

const SizedBox(height: 24),

const Text(
  'Today',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        _buildSalesCard(),

        const SizedBox(height: 24),

        const Text(
          'Order Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons
                    .notifications_active_outlined,
                title: 'New',
                value:
                    _newOrders.toString(),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons
                    .restaurant_outlined,
                title: 'Preparing',
                value:
                    _preparingOrders
                        .toString(),
                color: Colors.blue,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons
                    .check_circle_outline_rounded,
                title: 'Ready',
                value:
                    _readyOrders.toString(),
                color:
                    Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon:
                    Icons.done_all_rounded,
                title: 'Completed',
                value:
                    _completedOrders
                        .toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        const Text(
          'Recent Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        if (_recentOrders.isEmpty)
          _buildEmptyOrders()
        else
          ..._recentOrders.map(
            (order) =>
                _buildOrderCard(order),
          ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HalalFoodTheme
            .primaryGreen
            .withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome, Restaurant Owner',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _restaurantName ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color:
                  HalalFoodTheme
                      .primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage your restaurant orders here.',
            style: TextStyle(
              color:
                  HalalFoodTheme
                      .textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: HalalFoodTheme
                    .primaryGreen
                    .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 28,
                color:
                    HalalFoodTheme
                        .primaryGreen,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Sales",
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                ],
              ),
            ),
            Text(
              '₱${_todaySales.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.w800,
                color:
                    HalalFoodTheme
                        .primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons
                  .receipt_long_outlined,
              size: 52,
              color: HalalFoodTheme
                  .primaryGreen
                  .withValues(
                alpha: 0.55,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Customer orders will appear here.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
  ) {
    final id =
        order['id']?.toString() ?? '';

    final status =
        order['status']?.toString() ??
            'pending';

    final total =
        (order['total_amount'] as num?)
                ?.toDouble() ??
            0;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  OwnerOrderDetailsScreen(
                order: order,
              ),
            ),
          );
        },
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HalalFoodTheme
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
            Icons
                .receipt_long_rounded,
            color:
                HalalFoodTheme
                    .primaryGreen,
          ),
        ),
        title: Text(
          '#${_shortOrderId(id)}',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          _formatStatus(status),
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w700,
            color:
                _statusColor(status),
          ),
        ),
        trailing: Text(
          '₱${total.toStringAsFixed(2)}',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatCard
    extends StatelessWidget {
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
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
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
