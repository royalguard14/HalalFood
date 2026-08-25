import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import 'owner_dashboard_screen.dart';
import 'owner_submit_restaurant_screen.dart';
import '../../auth/screens/login_screen.dart';

class OwnerRestaurantSelectionScreen extends StatefulWidget {
  const OwnerRestaurantSelectionScreen({super.key});

  @override
  State<OwnerRestaurantSelectionScreen> createState() =>
      _OwnerRestaurantSelectionScreenState();
}

class _OwnerRestaurantSelectionScreenState
    extends State<OwnerRestaurantSelectionScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User is not authenticated.');

      final response = await _supabase
          .from('restaurants')
          .select('id, name, is_active, halal_status, city, created_at')
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _restaurants = (response as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
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

  Future<void> _addRestaurant() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const OwnerSubmitRestaurantScreen(),
      ),
    );

    if (created == true) {
      await _loadRestaurants();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant submitted. Waiting for admin approval.'),
        ),
      );
    }
  }

  void _openRestaurant(Map<String, dynamic> restaurant) {
    final active = restaurant['is_active'] == true;
    if (!active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This restaurant is still waiting for admin approval.'),
        ),
      );
      return;
    }

    final id = restaurant['id']?.toString();
    final name = restaurant['name']?.toString() ?? 'Restaurant';
    if (id == null || id.isEmpty) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OwnerDashboardScreen(
          restaurantId: id,
          restaurantName: name,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Restaurants',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addRestaurant,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Restaurant'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadRestaurants,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Unable to load restaurants',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: _loadRestaurants, child: const Text('Try Again')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Restaurants',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Add your restaurant and wait for admin approval before managing it.',
                  style: TextStyle(color: HalalFoodTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_restaurants.isEmpty)
            _emptyState()
          else
            ..._restaurants.map(_buildRestaurantCard),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
        child: Column(
          children: [
            const Icon(
              Icons.store_mall_directory_outlined,
              size: 64,
              color: HalalFoodTheme.primaryGreen,
            ),
            const SizedBox(height: 18),
            const Text(
              'You have no restaurant yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your restaurant and submit it to the administrator for approval.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HalalFoodTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addRestaurant,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Add My Restaurant'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final name = restaurant['name']?.toString() ?? 'Unnamed Restaurant';
    final active = restaurant['is_active'] == true;
    final city = restaurant['city']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openRestaurant(restaurant),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: HalalFoodTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(city, style: const TextStyle(color: HalalFoodTheme.textSecondary)),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.green.withValues(alpha: 0.10)
                            : Colors.orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        active ? 'Approved' : 'Pending Approval',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                active ? Icons.chevron_right_rounded : Icons.hourglass_top_rounded,
                color: active ? null : Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
