import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import 'developer_restaurant_control_screen.dart';

class DeveloperRestaurantManagementScreen extends StatefulWidget {
  const DeveloperRestaurantManagementScreen({super.key});

  @override
  State<DeveloperRestaurantManagementScreen> createState() =>
      _DeveloperRestaurantManagementScreenState();
}

class _DeveloperRestaurantManagementScreenState
    extends State<DeveloperRestaurantManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  String _search = '';
  List<Map<String, dynamic>> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await _supabase
          .from('restaurants')
          .select('id, name, city, province, owner_id, halal_status, is_active, is_featured, average_rating, review_count, created_at')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _restaurants = (response as List).map((row) => Map<String, dynamic>.from(row)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _search.toLowerCase();
    if (query.isEmpty) return _restaurants;
    return _restaurants.where((r) {
      final name = r['name']?.toString().toLowerCase() ?? '';
      final city = r['city']?.toString().toLowerCase() ?? '';
      final province = r['province']?.toString().toLowerCase() ?? '';
      return name.contains(query) || city.contains(query) || province.contains(query);
    }).toList();
  }

  Future<void> _openControl(Map<String, dynamic> restaurant) async {
    final id = restaurant['id']?.toString();
    final name = restaurant['name']?.toString() ?? 'Restaurant';
    if (id == null || id.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeveloperRestaurantControlScreen(restaurantId: id, restaurantName: name)));
  }

  Future<void> _deleteRestaurant(Map<String, dynamic> restaurant) async {
    if (_deleting) return;
    final id = restaurant['id']?.toString();
    final name = restaurant['name']?.toString() ?? 'this restaurant';
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.red),
          SizedBox(width: 10),
          Expanded(child: Text('Permanently Delete Restaurant')),
        ]),
        content: Text(
          'This will permanently delete "$name" and its related platform data, including orders, order items, payments, menus, subscriptions, subscription payments, halal verification, photos, promos, favorites, hours and restaurant categories.\n\nThe restaurant owner account and customer accounts will NOT be deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final result = await _supabase.rpc(
        'developer_delete_restaurant',
        params: {'p_restaurant_id': id},
      );
      await _load();
      if (!mounted) return;
      final deleted = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Restaurant deleted. Orders: ${deleted['orders'] ?? 0} • Payments: ${deleted['payments'] ?? 0} • Menu items: ${deleted['menu_items'] ?? 0}'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Text('Delete failed: $e'),
      ));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _halalLabel(String value) => switch (value) {
    'muslim_owned' => 'Muslim Owned',
    'halal_verified' => 'Halal Verified',
    'certified_halal' => 'Certified Halal',
    _ => 'Unverified',
  };

  @override
  Widget build(BuildContext context) {
    final restaurants = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer • Restaurants', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _loading || _deleting ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: .18)),
                        ),
                        child: const Text(
                          'Developer-only destructive control. Deleting a restaurant removes its application data and cannot be undone. Owner and customer accounts are preserved.',
                          style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _search = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search restaurant...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.isEmpty ? null : IconButton(
                            onPressed: () { _searchController.clear(); setState(() => _search = ''); },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('${restaurants.length} restaurant${restaurants.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700, color: HalalFoodTheme.textSecondary)),
                      const SizedBox(height: 8),
                      if (restaurants.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 70), child: Center(child: Text('No restaurants found.')))
                      else
                        ...restaurants.map(_restaurantCard),
                    ],
                  ),
                ),
    );
  }

  Widget _restaurantCard(Map<String, dynamic> restaurant) {
    final active = restaurant['is_active'] == true;
    final halal = restaurant['halal_status']?.toString() ?? 'unverified';
    final location = [restaurant['city']?.toString(), restaurant['province']?.toString()]
        .where((value) => value != null && value.trim().isNotEmpty)
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(restaurant['name']?.toString() ?? 'Unnamed Restaurant', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (restaurant['is_featured'] == true) const Icon(Icons.star_rounded, color: Colors.amber),
          ]),
          if (location.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(location, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary))),
          const SizedBox(height: 9),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _Badge(_halalLabel(halal), Colors.green),
            _Badge(active ? 'Active' : 'Inactive', active ? Colors.green : Colors.grey),
            _Badge('★ ${restaurant['average_rating'] ?? 0} (${restaurant['review_count'] ?? 0})', Colors.amber.shade800),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _deleting ? null : () => _openControl(restaurant),
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('Restaurant Control • Cash & GCash Vault', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleting ? null : () => _deleteRestaurant(restaurant),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade300)),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Permanently Delete Restaurant + Related Data', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 44),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
    ]),
  ));
}
