import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import 'owner_dashboard_screen.dart';

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
      if (user == null) {
        throw Exception('User is not authenticated.');
      }

      final response = await _supabase
          .from('restaurants')
          .select('id, name')
          .eq('owner_id', user.id)
          .order('name', ascending: true);

      final restaurants = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
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

  void _openRestaurant(Map<String, dynamic> restaurant) {
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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Restaurant',
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
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load restaurants',
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
            ElevatedButton(
              onPressed: _loadRestaurants,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_restaurants.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRestaurants,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 130),
            Icon(
              Icons.store_mall_directory_outlined,
              size: 64,
              color: HalalFoodTheme.primaryGreen,
            ),
            SizedBox(height: 18),
            Text(
              'No restaurants linked to this account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Please ask the administrator to link a restaurant to your owner account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HalalFoodTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                  'Select which restaurant you want to manage.',
                  style: TextStyle(color: HalalFoodTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._restaurants.map(_buildRestaurantCard),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final name = restaurant['name']?.toString() ?? 'Unnamed Restaurant';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
          child: const Icon(
            Icons.restaurant_rounded,
            color: HalalFoodTheme.primaryGreen,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Open restaurant dashboard'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openRestaurant(restaurant),
      ),
    );
  }
}
