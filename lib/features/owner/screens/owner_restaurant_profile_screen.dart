import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerRestaurantProfileScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerRestaurantProfileScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerRestaurantProfileScreen> createState() => _OwnerRestaurantProfileScreenState();
}

class _OwnerRestaurantProfileScreenState extends State<OwnerRestaurantProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.restaurantName;
    _loadRestaurant();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurant() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final restaurant = await _supabase
          .from('restaurants')
          .select('id, name')
          .eq('id', widget.restaurantId)
          .maybeSingle();

      if (restaurant == null) {
        throw Exception('Restaurant not found.');
      }

      if (!mounted) return;
      _nameController.text = restaurant['name']?.toString() ?? '';
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveRestaurant() async {
    final name = _nameController.text.trim();
    if (_isSaving) return;

    if (name.isEmpty) {
      _showMessage('Restaurant name cannot be empty.', error: true);
      return;
    }

    try {
      setState(() => _isSaving = true);

      await _supabase
          .from('restaurants')
          .update({'name': name})
          .eq('id', widget.restaurantId);

      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Restaurant profile updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Unable to update restaurant profile:\n$e', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading || _isSaving ? null : _loadRestaurant,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Unable to load restaurant profile', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _loadRestaurant, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRestaurant,
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
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: HalalFoodTheme.primaryGreen,
                  child: Icon(Icons.restaurant_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Restaurant Information', style: TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary)),
                      const SizedBox(height: 3),
                      Text(widget.restaurantName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Basic Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Restaurant Name',
              hintText: 'Enter restaurant name',
              prefixIcon: Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveRestaurant(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRestaurant,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
