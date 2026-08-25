import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../data/owner_restaurant_repository.dart';
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
  final _restaurantRepository = OwnerRestaurantRepository();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _restaurants = [];
  final Set<String> _pendingVerificationIds = {};
  final Set<String> _requestingVerificationIds = {};

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
      final restaurants = await _restaurantRepository.getMyRestaurants();
      final pendingIds = <String>{};

      for (final restaurant in restaurants) {
        final id = restaurant['id']?.toString();
        if (id == null || id.isEmpty) continue;
        if (await _restaurantRepository.hasPendingVerification(
          restaurantId: id,
        )) {
          pendingIds.add(id);
        }
      }

      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _pendingVerificationIds
          ..clear()
          ..addAll(pendingIds);
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
          content: Text(
            'Restaurant added. Halal verification can be requested separately.',
          ),
        ),
      );
    }
  }

  Future<void> _requestHalalVerification(
    Map<String, dynamic> restaurant,
  ) async {
    final id = restaurant['id']?.toString();
    final name = restaurant['name']?.toString() ?? 'Restaurant';
    if (id == null || id.isEmpty || _requestingVerificationIds.contains(id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Request Halal Verification',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Send a halal verification request for "$name" to the administrator?\n\n'
          'The restaurant will remain Unverified until the admin reviews and approves the request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _requestingVerificationIds.add(id));
    try {
      await _restaurantRepository.requestHalalVerification(
        restaurantId: id,
      );

      if (!mounted) return;
      setState(() => _pendingVerificationIds.add(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Halal verification request sent to the admin.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send verification request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requestingVerificationIds.remove(id));
      }
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

  String _halalStatusLabel(String? status) {
    switch (status) {
      case 'muslim_owned':
        return 'Muslim Owned';
      case 'halal_verified':
        return 'Halal Verified';
      case 'certified_halal':
        return 'Certified Halal';
      case 'unverified':
      default:
        return 'Unverified';
    }
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
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadRestaurants,
              child: const Text('Try Again'),
            ),
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
                  'Add your restaurant first. Halal verification is a separate request that you can send when ready.',
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
    final id = restaurant['id']?.toString();
    final name = restaurant['name']?.toString() ?? 'Unnamed Restaurant';
    final active = restaurant['is_active'] == true;
    final city = restaurant['city']?.toString().trim() ?? '';
    final halalStatus = restaurant['halal_status']?.toString() ?? 'unverified';
    final pendingVerification = id != null &&
        _pendingVerificationIds.contains(id);
    final requesting = id != null && _requestingVerificationIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openRestaurant(restaurant),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            city,
                            style: const TextStyle(
                              color: HalalFoodTheme.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _StatusPill(
                              label: active ? 'Approved' : 'Pending Approval',
                              color: active ? Colors.green : Colors.orange,
                            ),
                            _StatusPill(
                              label: _halalStatusLabel(halalStatus),
                              color: halalStatus == 'unverified'
                                  ? Colors.grey
                                  : Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    active
                        ? Icons.chevron_right_rounded
                        : Icons.hourglass_top_rounded,
                    color: active ? null : Colors.orange,
                  ),
                ],
              ),
              if (halalStatus == 'unverified') ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: pendingVerification
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.hourglass_top_rounded),
                          label: const Text('Halal Verification Pending'),
                        )
                      : OutlinedButton.icon(
                          onPressed: requesting || id == null
                              ? null
                              : () => _requestHalalVerification(restaurant),
                          icon: requesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: Text(
                            requesting
                                ? 'Sending Request...'
                                : 'Request Halal Verification',
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color.shade700,
        ),
      ),
    );
  }
}
