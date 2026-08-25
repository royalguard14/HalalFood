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
  State<OwnerMenuManagementScreen> createState() =>
      _OwnerMenuManagementScreenState();
}

class _OwnerMenuManagementScreenState
    extends State<OwnerMenuManagementScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];
  String? _selectedCategoryId;

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
      // Owner menu categories are restaurant-specific.
      // These are intentionally loaded from menu_categories, not food_categories.
      final categoriesResponse = await _supabase
          .from('menu_categories')
          .select('id, restaurant_id, name, description, sort_order, is_active')
          .eq('restaurant_id', widget.restaurantId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final itemsResponse = await _supabase
          .from('menu_items')
          .select(
            'id, restaurant_id, category_id, name, description, price, image_url, is_available, is_featured',
          )
          .eq('restaurant_id', widget.restaurantId)
          .order('is_featured', ascending: false)
          .order('name', ascending: true);

      if (!mounted) return;

      final categories = (categoriesResponse as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final items = (itemsResponse as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final categoryIds = categories
          .map((category) => category['id']?.toString())
          .whereType<String>()
          .toSet();

      if (_selectedCategoryId != null &&
          !categoryIds.contains(_selectedCategoryId)) {
        _selectedCategoryId = null;
      }

      setState(() {
        _categories = categories;
        _items = items;
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
      if (category['id']?.toString() == id) {
        return category['name']?.toString() ?? 'Category';
      }
    }
    return 'Uncategorized';
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategoryId == null) return _items;

    return _items
        .where(
          (item) =>
              item['category_id']?.toString() == _selectedCategoryId,
        )
        .toList();
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

    if (!_categories.any(
      (category) => category['id']?.toString() == selectedCategory,
    )) {
      selectedCategory = _categories.isEmpty
          ? null
          : _categories.first['id']?.toString();
    }

    return showDialog<_Draft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  onChanged: (value) => itemName = value,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
                  onChanged: (value) => itemDescription = value,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: price,
                  onChanged: (value) => itemPrice = value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Menu Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    final id = category['id']?.toString();
                    if (id == null) return null;

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        category['name']?.toString() ?? 'Category',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).whereType<DropdownMenuItem<String>>().toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available'),
                  value: isAvailable,
                  onChanged: (value) {
                    setDialogState(() => isAvailable = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Best Seller'),
                  value: isFeatured,
                  onChanged: (value) {
                    setDialogState(() => isFeatured = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsedPrice = double.tryParse(itemPrice.trim());

                if (itemName.trim().isEmpty ||
                    parsedPrice == null ||
                    parsedPrice < 0 ||
                    selectedCategory == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a valid name, price, and menu category.',
                      ),
                    ),
                  );
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
              child: Text(
                title == 'Add Menu Item' ? 'Add Item' : 'Save',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    if (_isSaving || _categories.isEmpty) return;

    // If a category filter is active, use that category as the default.
    final draft = await _dialog(
      title: 'Add Menu Item',
      categoryId: _selectedCategoryId,
    );

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

      await _supabase
          .from('menu_items')
          .update({
            'category_id': draft.categoryId,
            'name': draft.name,
            'description': draft.description.isEmpty
                ? null
                : draft.description,
            'price': draft.price,
            'is_available': draft.available,
            'is_featured': draft.featured,
          })
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);

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
        title: const Text(
          'Remove Menu Item?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Permanently remove "$name"? This is different from Available/Unavailable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
        _showError(
          'This item is already in an order. Use Available/Unavailable instead.',
        );
        return;
      }

      await _supabase
          .from('menu_item_categories')
          .delete()
          .eq('menu_item_id', id);

      await _supabase
          .from('menu_items')
          .delete()
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to remove menu item:\n$e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Menu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadMenu,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load menu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMenu,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Menu',
                  style: TextStyle(
                    fontSize: 13,
                    color: HalalFoodTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.restaurantName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_categories.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No menu categories are available yet. Create a menu category first.',
                ),
              ),
            )
          else ...[
            _buildCategoryFilter(),
            const SizedBox(height: 18),
            _buildMenuList(),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter Menu',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _categoryFilterChip(
                  label: 'All',
                  selected: _selectedCategoryId == null,
                  onTap: () {
                    setState(() => _selectedCategoryId = null);
                  },
                );
              }

              final category = _categories[index - 1];
              final id = category['id']?.toString();
              if (id == null) return const SizedBox.shrink();

              return _categoryFilterChip(
                label: category['name']?.toString() ?? 'Category',
                selected: _selectedCategoryId == id,
                onTap: () {
                  setState(() => _selectedCategoryId = id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected
            ? Colors.white
            : HalalFoodTheme.textPrimary,
      ),
      selectedColor: HalalFoodTheme.primaryGreen,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected
            ? HalalFoodTheme.primaryGreen
            : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildMenuList() {
    final items = _filteredItems;

    if (items.isEmpty) {
      final message = _selectedCategoryId == null
          ? 'No menu items have been added yet.'
          : 'No menu items in ${_categoryName(_selectedCategoryId)}.';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                size: 52,
                color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap Add Item to create a menu item.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 20,
                  color: HalalFoodTheme.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_selectedCategoryId != null)
                  Text(
                    _categoryName(_selectedCategoryId),
                    style: const TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.asMap().entries.map(
            (entry) => Column(
              children: [
                _itemTile(entry.value),
                if (entry.key != items.length - 1)
                  const Divider(height: 1, indent: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final available = item['is_available'] == true;
    final featured = item['is_featured'] == true;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      onTap: _isSaving ? null : () => _edit(item),
      leading: CircleAvatar(
        backgroundColor: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
        child: const Icon(
          Icons.fastfood_rounded,
          color: HalalFoodTheme.primaryGreen,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (featured)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                Icons.star_rounded,
                size: 17,
                color: Colors.amber,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Flexible(
              child: Text(
                _categoryName(item['category_id']?.toString()),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HalalFoodTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              ' • ',
              style: TextStyle(color: HalalFoodTheme.textSecondary),
            ),
            Text(
              available ? 'Available' : 'Unavailable',
              style: TextStyle(
                color: available ? Colors.green : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '₱${price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _edit(item);
              if (value == 'remove') _remove(item);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove'),
              ),
            ],
          ),
        ],
      ),
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
