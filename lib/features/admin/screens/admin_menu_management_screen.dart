import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../data/admin_repository.dart';
import '../../owner/screens/owner_menu_management_screen.dart';

class AdminMenuManagementScreen extends StatefulWidget {
  const AdminMenuManagementScreen({super.key});

  @override
  State<AdminMenuManagementScreen> createState() =>
      _AdminMenuManagementScreenState();
}

class _AdminMenuManagementScreenState
    extends State<AdminMenuManagementScreen> {
  final _adminRepository = AdminRepository();
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _search = '';
  List<Map<String, dynamic>> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final restaurants = await _adminRepository.getRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRestaurants {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _restaurants;
    return _restaurants.where((r) {
      final name = r['name']?.toString().toLowerCase() ?? '';
      final city = r['city']?.toString().toLowerCase() ?? '';
      return name.contains(q) || city.contains(q);
    }).toList();
  }

  Future<void> _openMenu(Map<String, dynamic> restaurant) async {
    final id = restaurant['id']?.toString();
    if (id == null || id.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerMenuManagementScreen(
          restaurantId: id,
          restaurantName: restaurant['name']?.toString() ?? 'Restaurant',
        ),
      ),
    );
  }

  Future<int> _getMenuCount(String restaurantId) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select('id')
          .eq('restaurant_id', restaurantId);
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = _filteredRestaurants;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text(
          'Menu Management',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadRestaurants,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadRestaurants)
              : RefreshIndicator(
                  onRefresh: _loadRestaurants,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              HalalFoodTheme.primaryGreen,
                              HalalFoodTheme.primaryGreen.withValues(alpha: .82),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.restaurant_menu_rounded,
                                color: Colors.white, size: 38),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Restaurant Menus',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Choose a restaurant to add, edit, or manage its menu items.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _search = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search restaurant or city...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _search = '');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${restaurants.length} restaurant${restaurants.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: HalalFoodTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (restaurants.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 70),
                          child: Center(child: Text('No restaurants found.')),
                        )
                      else
                        ...restaurants.map(
                          (restaurant) => _RestaurantMenuTile(
                            restaurant: restaurant,
                            menuCount: _getMenuCount(
                              restaurant['id'].toString(),
                            ),
                            onTap: () => _openMenu(restaurant),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _RestaurantMenuTile extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final Future<int> menuCount;
  final VoidCallback onTap;

  const _RestaurantMenuTile({
    required this.restaurant,
    required this.menuCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = restaurant['is_active'] == true;
    final halal = restaurant['halal_status']?.toString() ?? 'unverified';
    final city = restaurant['city']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: HalalFoodTheme.primaryGreen.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: HalalFoodTheme.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant['name']?.toString() ?? 'Unnamed Restaurant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        city,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SmallBadge(
                          active ? 'Active' : 'Inactive',
                          active ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        _SmallBadge(
                          halal == 'unverified' ? 'Unverified' : 'Halal',
                          halal == 'unverified' ? Colors.orange : Colors.teal,
                        ),
                        const SizedBox(width: 6),
                        FutureBuilder<int>(
                          future: menuCount,
                          builder: (context, snapshot) => _SmallBadge(
                            '${snapshot.data ?? 0} items',
                            Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                'Unable to load restaurants',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
}
