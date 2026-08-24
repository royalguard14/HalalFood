import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerMenuManagementScreen extends StatefulWidget {
  const OwnerMenuManagementScreen({super.key});

  @override
  State<OwnerMenuManagementScreen> createState() =>
      _OwnerMenuManagementScreenState();
}

class _OwnerMenuManagementScreenState extends State<OwnerMenuManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _restaurantId;
  String? _restaurantName;
  String _selectedCategoryId = 'all';

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _menuItems = [];

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
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User is not authenticated.');

      final restaurant = await _supabase
          .from('restaurants')
          .select('id, name')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (restaurant == null) {
        throw Exception('No restaurant is linked to this account.');
      }

      final restaurantId = restaurant['id'].toString();

      final categoriesResponse = await _supabase
          .from('food_categories')
          .select('id, name, slug, icon, is_active, sort_order')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final itemsResponse = await _supabase
          .from('menu_items')
          .select(
            'id, restaurant_id, category_id, name, description, price, '
            'image_url, is_available, is_featured, created_at, updated_at',
          )
          .eq('restaurant_id', restaurantId)
          .order('is_featured', ascending: false)
          .order('name', ascending: true);

      final categories = (categoriesResponse as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final items = (itemsResponse as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      final categoryStillExists = _selectedCategoryId == 'all' ||
          categories.any(
            (category) =>
                category['id']?.toString() == _selectedCategoryId,
          );

      setState(() {
        _restaurantId = restaurantId;
        _restaurantName = restaurant['name']?.toString() ?? '';
        _categories = categories;
        _menuItems = items;
        if (!categoryStillExists) _selectedCategoryId = 'all';
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

  List<Map<String, dynamic>> _itemsForCategory(String categoryId) {
    return _menuItems
        .where((item) => item['category_id']?.toString() == categoryId)
        .toList();
  }

  String _categoryName(String? categoryId) {
    for (final category in _categories) {
      if (category['id']?.toString() == categoryId) {
        return category['name']?.toString() ?? 'Category';
      }
    }
    return 'Uncategorized';
  }

  Future<_MenuItemDraft?> _showMenuItemDialog({
    required String title,
    String? initialCategoryId,
    String initialName = '',
    String initialDescription = '',
    String initialPrice = '',
    bool initialAvailable = true,
    bool initialBestSeller = false,
  }) async {
    String name = initialName;
    String description = initialDescription;
    String priceText = initialPrice;
    String? selectedCategoryId = initialCategoryId;
    bool isAvailable = initialAvailable;
    bool isBestSeller = initialBestSeller;

    if (selectedCategoryId == null ||
        !_categories.any(
          (category) => category['id']?.toString() == selectedCategoryId,
        )) {
      selectedCategoryId = _selectedCategoryId == 'all'
          ? _categories.first['id']?.toString()
          : _selectedCategoryId;
    }

    return showDialog<_MenuItemDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      autofocus: true,
                      initialValue: initialName,
                      onChanged: (value) => name = value,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g. Chicken Rice',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: initialDescription,
                      onChanged: (value) => description = value,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: initialPrice,
                      onChanged: (value) => priceText = value,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Food Category',
                        helperText: 'Categories are managed by the admin.',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        final id = category['id']?.toString();
                        if (id == null) return null;
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            category['name']?.toString() ?? 'Category',
                          ),
                        );
                      }).whereType<DropdownMenuItem<String>>().toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
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
                      subtitle: const Text(
                        'Highlight this item as a restaurant best seller.',
                      ),
                      value: isBestSeller,
                      onChanged: (value) {
                        setDialogState(() => isBestSeller = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final cleanName = name.trim();
                    final price = double.tryParse(priceText.trim());

                    if (cleanName.isEmpty ||
                        price == null ||
                        price < 0 ||
                        selectedCategoryId == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid name, price, and category.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Return a plain data object. No TextEditingController is
                    // disposed while the dialog route is being removed.
                    Navigator.of(dialogContext).pop(
                      _MenuItemDraft(
                        name: cleanName,
                        description: description.trim(),
                        price: price,
                        categoryId: selectedCategoryId!,
                        isAvailable: isAvailable,
                        isBestSeller: isBestSeller,
                      ),
                    );
                  },
                  child: Text(title == 'Add Menu Item' ? 'Add Item' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addMenuItem({String? initialCategoryId}) async {
    if (_restaurantId == null) return;

    if (_categories.isEmpty) {
      _showError(
        'No food categories are available yet. Please ask the admin to add categories.',
      );
      return;
    }

    final draft = await _showMenuItemDialog(
      title: 'Add Menu Item',
      initialCategoryId: initialCategoryId,
    );

    if (draft == null || !mounted || _restaurantId == null) return;

    try {
      setState(() => _isSaving = true);

      await _supabase.from('menu_items').insert({
        'restaurant_id': _restaurantId,
        'category_id': draft.categoryId,
        'name': draft.name,
        'description': draft.description.isEmpty ? null : draft.description,
        'price': draft.price,
        'image_url': null,
        'is_available': draft.isAvailable,
        'is_featured': draft.isBestSeller,
      });

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to add menu item:\n$e');
    }
  }

  Future<void> _editMenuItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty || _categories.isEmpty) return;

    final draft = await _showMenuItemDialog(
      title: 'Edit Menu Item',
      initialCategoryId: item['category_id']?.toString(),
      initialName: item['name']?.toString() ?? '',
      initialDescription: item['description']?.toString() ?? '',
      initialPrice: ((item['price'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
      initialAvailable: item['is_available'] == true,
      initialBestSeller: item['is_featured'] == true,
    );

    if (draft == null || !mounted || _restaurantId == null) return;

    try {
      setState(() => _isSaving = true);

      await _supabase.from('menu_items').update({
        'category_id': draft.categoryId,
        'name': draft.name,
        'description': draft.description.isEmpty ? null : draft.description,
        'price': draft.price,
        'is_available': draft.isAvailable,
        'is_featured': draft.isBestSeller,
      }).eq('id', id).eq('restaurant_id', _restaurantId!);

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to update menu item:\n$e');
    }
  }

  Future<void> _removeMenuItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty || _restaurantId == null) return;

    final name = item['name']?.toString() ?? 'this item';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Remove Menu Item?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Remove "$name" from your menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isSaving = true);

      await _supabase
          .from('menu_items')
          .update({'is_available': false})
          .eq('id', id)
          .eq('restaurant_id', _restaurantId!);

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
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMenu,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton:
          _isLoading || _restaurantId == null || _categories.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _isSaving ? null : _addMenuItem,
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
      return RefreshIndicator(
        onRefresh: _loadMenu,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 150),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 60,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _loadMenu,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final uncategorized = _menuItems
        .where(
          (item) => !_categories.any(
            (category) =>
                category['id']?.toString() == item['category_id']?.toString(),
          ),
        )
        .toList();

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          _buildRestaurantHeader(),
          const SizedBox(height: 20),
          _buildSummaryCard(),
          const SizedBox(height: 24),
          const Text(
            'Food Categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Categories are managed by the admin. Add your restaurant\'s menu items under the appropriate category.',
            style: TextStyle(
              fontSize: 13,
              color: HalalFoodTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (_categories.isEmpty)
            _buildNoCategories()
          else
            ..._categories.map(_buildCategorySection),
          if (uncategorized.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildUncategorizedSection(uncategorized),
          ],
        ],
      ),
    );
  }

  Widget _buildRestaurantHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 28,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  _restaurantName ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final available =
        _menuItems.where((item) => item['is_available'] == true).length;
    final bestSellers =
        _menuItems.where((item) => item['is_featured'] == true).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.restaurant_menu_rounded,
                title: 'Items',
                value: '${_menuItems.length}',
              ),
            ),
            Expanded(
              child: _SummaryItem(
                icon: Icons.check_circle_outline_rounded,
                title: 'Available',
                value: '$available',
              ),
            ),
            Expanded(
              child: _SummaryItem(
                icon: Icons.star_outline_rounded,
                title: 'Best Sellers',
                value: '$bestSellers',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCategories() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: const [
            Icon(
              Icons.category_outlined,
              size: 54,
              color: HalalFoodTheme.primaryGreen,
            ),
            SizedBox(height: 12),
            Text(
              'No food categories yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'The admin has not created any food categories yet. Please ask the admin to add them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HalalFoodTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> category) {
    final categoryId = category['id']?.toString() ?? '';
    final items = _itemsForCategory(categoryId);
    final categoryName = category['name']?.toString() ?? 'Category';
    final icon = category['icon']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon == null || icon.isEmpty
                    ? Icons.category_rounded
                    : Icons.restaurant_menu_rounded,
                color: HalalFoodTheme.primaryGreen,
              ),
            ),
            title: Text(
              categoryName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${items.length} item${items.length == 1 ? '' : 's'}',
            ),
            trailing: IconButton(
              tooltip: 'Add item to $categoryName',
              onPressed: _isSaving
                  ? null
                  : () => _addMenuItem(initialCategoryId: categoryId),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No menu items in this category yet.',
                style: TextStyle(color: HalalFoodTheme.textSecondary),
              ),
            )
          else
            ...items.map(_buildMenuItemTile),
        ],
      ),
    );
  }

  Widget _buildUncategorizedSection(List<Map<String, dynamic>> items) {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.help_outline_rounded),
            title: Text(
              'Uncategorized',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('Items whose category is no longer available.'),
          ),
          ...items.map(_buildMenuItemTile),
        ],
      ),
    );
  }

  Widget _buildMenuItemTile(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final isAvailable = item['is_available'] == true;
    final isBestSeller = item['is_featured'] == true;
    final categoryName = _categoryName(item['category_id']?.toString());

    return InkWell(
      onTap: _isSaving ? null : () => _editMenuItem(item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fastfood_rounded,
                color: HalalFoodTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isBestSeller)
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
                  Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '₱${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: HalalFoodTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAvailable ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editMenuItem(item);
                } else if (value == 'remove') {
                  _removeMenuItem(item);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemDraft {
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final bool isAvailable;
  final bool isBestSeller;

  const _MenuItemDraft({
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.isAvailable,
    required this.isBestSeller,
  });
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: HalalFoodTheme.primaryGreen),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: HalalFoodTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
