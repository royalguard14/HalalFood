import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isOnline = false;
  bool _loadingDeliveries = true;
  bool _takingDelivery = false;
  String? _deliveryError;
  List<Map<String, dynamic>> _availableDeliveries = [];
  Position? _riderPosition;

  @override
  void initState() {
    super.initState();
    _loadAvailableDeliveries();
    _loadRiderPosition();
  }

  Future<void> _loadRiderPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _riderPosition = position);
    } catch (_) {}
  }

  double? _distanceKm(
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
  ) {
    if (startLat == null ||
        startLng == null ||
        endLat == null ||
        endLng == null) {
      return null;
    }

    const earthRadiusKm = 6371.0;
    final dLat = (endLat - startLat) * math.pi / 180;
    final dLng = (endLng - startLng) * math.pi / 180;
    final lat1 = startLat * math.pi / 180;
    final lat2 = endLat * math.pi / 180;

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  String _formatDistance(double? km) {
    if (km == null) return 'Location unavailable';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _loadAvailableDeliveries() async {
    if (!mounted) return;
    setState(() {
      _loadingDeliveries = true;
      _deliveryError = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('delivery_assignments')
          .select('id, order_id, status, restaurant_food_advance, customer_collection_amount, created_at')
          .eq('status', 'available')
          .isFilter('rider_id', null)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        final assignments = List<Map<String, dynamic>>.from(rows);
        final orderIds = assignments
            .map((row) => row['order_id']?.toString())
            .whereType<String>()
            .toList();

        if (orderIds.isNotEmpty) {
          final orders = await Supabase.instance.client
              .from('orders')
              .select('id, restaurant_id, delivery_address_id')
              .inFilter('id', orderIds);

          final restaurantIds = orders
              .map((row) => row['restaurant_id']?.toString())
              .whereType<String>()
              .toSet()
              .toList();
          final addressIds = orders
              .map((row) => row['delivery_address_id']?.toString())
              .whereType<String>()
              .toSet()
              .toList();

          final restaurants = restaurantIds.isEmpty
              ? <dynamic>[]
              : await Supabase.instance.client
                  .from('restaurants')
                  .select('id, name, address, latitude, longitude')
                  .inFilter('id', restaurantIds);
          final addresses = addressIds.isEmpty
              ? <dynamic>[]
              : await Supabase.instance.client
                  .from('user_addresses')
                  .select('id, address_line, barangay, city, latitude, longitude')
                  .inFilter('id', addressIds);

          final orderById = {
            for (final row in orders) row['id'].toString(): row,
          };
          final restaurantById = {
            for (final row in restaurants) row['id'].toString(): row,
          };
          final addressById = {
            for (final row in addresses) row['id'].toString(): row,
          };

          for (final assignment in assignments) {
            final order = orderById[assignment['order_id']?.toString()];
            if (order == null) continue;
            assignment['restaurant'] =
                restaurantById[order['restaurant_id']?.toString()];
            assignment['customer_address'] =
                addressById[order['delivery_address_id']?.toString()];
          }
        }

        if (!mounted) return;
        setState(() {
          _availableDeliveries = assignments;
          _loadingDeliveries = false;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDeliveries = false;
        _deliveryError = e.toString();
      });
    }
  }

  Future<void> _takeDelivery(String assignmentId) async {
    if (_takingDelivery) return;
    setState(() {
      _takingDelivery = true;
      _deliveryError = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'rider_take_delivery',
        params: {'p_assignment_id': assignmentId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery accepted.')),
      );
      await _loadAvailableDeliveries();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deliveryError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to take delivery: ' + e.toString())),
      );
    } finally {
      if (mounted) setState(() => _takingDelivery = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.delivery_dining_rounded),
            SizedBox(width: 8),
            Text(
              'Driver Dashboard',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          children: [
            _welcomeCard(),
            const SizedBox(height: 16),
            _onlineCard(),
            const SizedBox(height: 16),
            _statsCard(),
            const SizedBox(height: 16),
            _sectionTitle('Available Deliveries'),
            const SizedBox(height: 10),
            _availableDeliveriesCard(),
            const SizedBox(height: 20),
            _sectionTitle('Current Delivery'),
            const SizedBox(height: 10),
            _emptyDeliveryCard(),
            const SizedBox(height: 20),
            _sectionTitle('Driver Tools'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _toolCard(
                    Icons.receipt_long_rounded,
                    'My Deliveries',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _toolCard(
                    Icons.account_balance_wallet_rounded,
                    'Earnings',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _toolCard(
                    Icons.location_on_rounded,
                    'Delivery Map',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _toolCard(
                    Icons.person_rounded,
                    'My Profile',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [HalalFoodTheme.primaryGreen, HalalFoodTheme.darkGreen],
        ),
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Driver',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Your delivery workspace',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (_isOnline ? Colors.green : Colors.grey)
                    .withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isOnline
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                color: _isOnline ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline ? 'You are Online' : 'You are Offline',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isOnline
                        ? 'Ready to receive delivery requests.'
                        : 'Go online when you are ready to deliver.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isOnline,
              onChanged: (value) => setState(() => _isOnline = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _statItem('0', 'Today'),
            _divider(),
            _statItem('₱0.00', 'Earnings'),
            _divider(),
            _statItem('0', 'Completed'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: HalalFoodTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 34, color: Colors.grey.shade200);
  }

  Widget _availableDeliveriesCard() {
    if (_loadingDeliveries) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_deliveryError != null && _availableDeliveries.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 10),
              const Text('Unable to load deliveries',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_deliveryError!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadAvailableDeliveries,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_availableDeliveries.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.local_shipping_outlined, size: 46, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              const Text('No available delivery',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('New delivery requests will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadAvailableDeliveries,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _availableDeliveries.map((delivery) {
        final orderId = delivery['order_id']?.toString() ?? '';
        final shortOrderId = orderId.length > 8
            ? orderId.substring(0, 8).toUpperCase()
            : orderId.toUpperCase();
        final advance = _toAmount(delivery['restaurant_food_advance']);
        final collection = _toAmount(delivery['customer_collection_amount']);
        final restaurant =
            Map<String, dynamic>.from(delivery['restaurant'] ?? const {});
        final customerAddress =
            Map<String, dynamic>.from(delivery['customer_address'] ?? const {});

        final restaurantLat = _toAmount(restaurant['latitude']);
        final restaurantLng = _toAmount(restaurant['longitude']);
        final customerLat = _toAmount(customerAddress['latitude']);
        final customerLng = _toAmount(customerAddress['longitude']);

        final riderToRestaurant = _distanceKm(
          _riderPosition?.latitude,
          _riderPosition?.longitude,
          restaurantLat,
          restaurantLng,
        );
        final restaurantToCustomer = _distanceKm(
          restaurantLat,
          restaurantLng,
          customerLat,
          customerLng,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: HalalFoodTheme.primaryGreen.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('AVAILABLE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    Text('#' + shortOrderId,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                if (advance != null) _deliveryAmountRow(
                  'Restaurant advance',
                  '₱' + advance.toStringAsFixed(2),
                ),
                if (collection != null) _deliveryAmountRow(
                  'Customer collection',
                  '₱' + collection.toStringAsFixed(2),
                ),
                const Divider(height: 20),
                _deliveryAmountRow(
                  'Rider → Restaurant',
                  _formatDistance(riderToRestaurant),
                ),
                _deliveryAmountRow(
                  'Restaurant → Customer',
                  _formatDistance(restaurantToCustomer),
                ),
                if (restaurant['name'] != null)
                  _deliveryAmountRow('Restaurant', restaurant['name'].toString()),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _takingDelivery ? null : () => _takeDelivery(delivery['id'].toString()),
                    icon: const Icon(Icons.delivery_dining_rounded),
                    label: const Text('Take Delivery'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  double? _toAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Widget _deliveryAmountRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _emptyDeliveryCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 46,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            const Text(
              'No active delivery',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Available delivery requests will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }

  Widget _toolCard(IconData icon, String title) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: HalalFoodTheme.primaryGreen),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
