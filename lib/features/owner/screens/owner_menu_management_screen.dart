import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerMenuManagementScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerMenuManagementScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerMenuManagementScreen> createState() => _OwnerMenuManagementScreenState();
}

class _OwnerMenuManagementScreenState extends State<OwnerMenuManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categoriesResponse = await _supabase
          .from('food_categories')
          .select('id, name, slug, icon, is_active, sort_order')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final itemsResponse = await _supabase
          .from('menu_items')
          .select('id, restaurant_id, category_id, name, description, price, image_url, is_available, is_featured')
          .eq('restaurant_id', widget.restaurantId)
          .order('is_featured', ascending: false)
          .order('name', ascending: true);

      if (!mounted) return;
      setState(() {
        _categories = (categoriesResponse as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _items = (itemsResponse as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSaving = false;
        _error = e.toString();
      });
    }
  }

  String _categoryName(String? id) {
    for (final category in _categories) {
      if (category['id']?.toString() == id) return category['name']?.toString() ?? 'Category';
    }
    return 'Uncategorized';
  }

  Future<_Draft?> _dialog({
    required String title,
    String? categoryId,
    String name = '',
    String description = '',
    String price = '',
    bool available = true,
    bool featured = false,
  }) async {
    String itemName = name;
    String itemDescription = description;
    String itemPrice = price;
    String? selectedCategory = categoryId;
    bool isAvailable = available;
    bool isFeatured = featured;

    if (!_categories.any((c) => c['id']?.toString() == selectedCategory)) {
      selectedCategory = _categories.isEmpty ? null : _categories.first['id']?.toString();
    }

    return showDialog<_Draft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  onChanged: (v) => itemName = v,
                  decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
                  onChanged: (v) => itemDescription = v,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: price,
                  onChanged: (v) => itemPrice = v,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price', prefixText: '₱ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Food Category', border: OutlineInputBorder()),
                  items: _categories.map((c) {
                    final id = c['id']?.toString();
                    if (id == null) return null;
                    return DropdownMenuItem(value: id, child: Text(c['name']?.toString() ?? 'Category'));
                  }).whereType<DropdownMenuItem<String>>().toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available'),
                  value: isAvailable,
                  onChanged: (v) => setDialogState(() => isAvailable = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Best Seller'),
                  value: isFeatured,
                  onChanged: (v) => setDialogState(() => isFeatured = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final parsedPrice = double.tryParse(itemPrice.trim());
                if (itemName.trim().isEmpty || parsedPrice == null || parsedPrice < 0 || selectedCategory == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Please enter a valid name, price, and category.')));
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _Draft(
                    name: itemName.trim(),
                    description: itemDescription.trim(),
                    price: parsedPrice,
                    categoryId: selectedCategory!,
                    available: isAvailable,
                    featured: isFeatured,
                  ),
                );
              },
              child: Text(title == 'Add Menu Item' ? 'Add Item' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add({String? categoryId}) async {
    if (_isSaving || _categories.isEmpty) return;
    final draft = await _dialog(title: 'Add Menu Item', categoryId: categoryId);
    if (draft == null || !mounted) return;

    try {
      setState(() => _isSaving = true);
      await _supabase.from('menu_items').insert({
        'restaurant_id': widget.restaurantId,
        'category_id': draft.categoryId,
        'name': draft.name,
        'description': draft.description.isEmpty ? null : draft.description,
        'price': draft.price,
        'image_url': null,
        'is_available': draft.available,
        'is_featured': draft.featured,
      });
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to add menu item:\n$e');
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    if (_isSaving) return;
    final id = item['id']?.toString();
    if (id == null) return;

    final draft = await _dialog(
      title: 'Edit Menu Item',
      categoryId: item['category_id']?.toString(),
      name: item['name']?.toString() ?? '',
      description: item['description']?.toString() ?? '',
      price: ((item['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
      available: item['is_available'] == true,
      featured: item['is_featured'] == true,
    );
    if (draft == null || !mounted) return;

    try {
      setState(() => _isSaving = true);
      await _supabase.from('menu_items').update({
        'category_id': draft.categoryId,
        'name': draft.name,
        'description': draft.description.isEmpty ? null : draft.description,
        'price': draft.price,
        'is_available': draft.available,
        'is_featured': draft.featured,
      }).eq('id', id).eq('restaurant_id', widget.restaurantId);
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to update menu item:\n$e');
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    if (_isSaving) return;
    final id = item['id']?.toString();
    if (id == null) return;
    final name = item['name']?.toString() ?? 'this item';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Menu Item?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Permanently remove "$name"? This is different from Available/Unavailable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isSaving = true);

      final references = await _supabase
          .from('order_items')
          .select('id')
          .eq('menu_item_id', id)
          .limit(1);

      if ((references as List).isNotEmpty) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        _showError('This item is already in an order. Use Available/Unavailable instead.');
        return;
      }

      await _supabase.from('menu_item_categories').delete().eq('menu_item_id', id);
      await _supabase.from('menu_items').delete().eq('id', id).eq('restaurant_id', widget.restaurantId);
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to remove menu item:\n$e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Menu', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _isLoading ? null : _loadMenu, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: _categories.isEmpty || _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSaving ? null : _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
        const SizedBox(height: 12),
        const Text('Unable to load menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadMenu, child: const Text('Try Again')),
      ])));
    }

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Restaurant Menu', style: TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(widget.restaurantName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 20),
          if (_categories.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No food categories are available yet.')))
          else
            ..._categories.map(_categorySection),
        ],
      ),
    );
  }

  Widget _categorySection(Map<String, dynamic> category) {
    final id = category['id']?.toString() ?? '';
    final items = _items.where((item) => item['category_id']?.toString() == id).toList();
    final name = category['name']?.toString() ?? 'Category';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        ListTile(
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${items.length} item${items.length == 1 ? '' : 's'}'),
          leading: const Icon(Icons.category_rounded, color: HalalFoodTheme.primaryGreen),
          trailing: IconButton(onPressed: _isSaving ? null : () => _add(categoryId: id), icon: const Icon(Icons.add_circle_outline_rounded)),
        ),
        const Divider(height: 1),
        if (items.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('No menu items in this category yet.', style: TextStyle(color: HalalFoodTheme.textSecondary)))
        else
          ...items.map(_itemTile),
      ]),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final available = item['is_available'] == true;
    final featured = item['is_featured'] == true;

    return ListTile(
      onTap: _isSaving ? null : () => _edit(item),
      leading: CircleAvatar(
        backgroundColor: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
        child: const Icon(Icons.fastfood_rounded, color: HalalFoodTheme.primaryGreen),
      ),
      title: Row(children: [
        Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (featured) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.star_rounded, size: 17, color: Colors.amber)),
      ]),
      subtitle: Text(
        '${_categoryName(item['category_id']?.toString())} • ${available ? 'Available' : 'Unavailable'}',
        style: TextStyle(color: available ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('₱${price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _edit(item);
            if (value == 'remove') _remove(item);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'remove', child: Text('Remove')),
          ],
        ),
      ]),
    );
  }
}

class _Draft {
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final bool available;
  final bool featured;

  const _Draft({
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.available,
    required this.featured,
  });
}
